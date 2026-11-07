# Userspace Boot Splash Configuration

This document provides the complete Ansible implementation for the userspace component of the Loiterix boot splash system.

**Repository**: `loiterix-platform` (ansible/)  
**Status**: Implementation required - kernel-side complete

## Overview

The userspace component maintains quiet boot after the kernel phase, ensuring systemd messages and getty prompts don't overwrite the display until the application is ready.

## Implementation

### 1. Create Ansible Task File

**File**: `ansible/tasks/boot-splash.yml`

```yaml
---
# Loiterix Boot Splash - Userspace Configuration
# Coordinates with kernel boot splash for seamless quiet boot experience
#
# Dependencies:
#   - Kernel: linux-image with Loiterix boot splash patch
#   - Boot params: quiet loglevel=3 console=tty1 console=ttyS0,115200n8
#
# This task configures:
#   1. Boot parameters (if not already set)
#   2. Systemd quiet mode
#   3. Getty suppression on tty1
#   4. Optional PSplash for extended splash

- name: Check if kernel supports boot splash
  command: zcat /proc/config.gz
  register: kernel_config
  changed_when: false
  failed_when: false

- name: Verify framebuffer and logo support
  assert:
    that:
      - "'CONFIG_LOGO=y' in kernel_config.stdout"
      - "'CONFIG_FRAMEBUFFER_CONSOLE=y' in kernel_config.stdout"
    fail_msg: "Kernel does not have boot splash support. Install linux-image with Loiterix patches."
    success_msg: "Kernel boot splash support verified"
  when: kernel_config.rc == 0

#
# Boot Parameters Configuration
#

- name: Detect bootloader configuration file
  stat:
    path: "{{ item }}"
  register: bootloader_configs
  loop:
    - /boot/extlinux/extlinux.conf
    - /boot/armbianEnv.txt
    - /boot/uEnv.txt
    - /boot/boot.ini

- name: Set bootloader config file
  set_fact:
    bootloader_config: "{{ item.item }}"
  when: item.stat.exists
  loop: "{{ bootloader_configs.results }}"
  loop_control:
    label: "{{ item.item }}"

- name: Fail if no bootloader config found
  fail:
    msg: "No bootloader configuration file found. Cannot set boot parameters."
  when: bootloader_config is not defined

- name: Configure boot parameters for quiet boot
  block:
    - name: Add quiet boot parameters (extlinux.conf)
      lineinfile:
        path: "{{ bootloader_config }}"
        regexp: '^(\s*APPEND\s+.*?)(?:\s+quiet\s+loglevel=\d+\s+vt\.global_cursor_default=\d+)?(\s*)$'
        line: '\1 quiet loglevel=3 vt.global_cursor_default=0\2'
        backrefs: yes
      when: "'extlinux.conf' in bootloader_config"
      notify: Reboot required

    - name: Add quiet boot parameters (armbianEnv.txt / uEnv.txt)
      lineinfile:
        path: "{{ bootloader_config }}"
        regexp: '^extraargs='
        line: 'extraargs=quiet loglevel=3 vt.global_cursor_default=0'
        create: yes
      when: "'Env.txt' in bootloader_config"
      notify: Reboot required

- name: Ensure console parameters are set
  block:
    - name: Check current boot parameters
      slurp:
        src: "{{ bootloader_config }}"
      register: bootloader_content

    - name: Verify console=tty1 is set
      assert:
        that: "'console=tty1' in bootloader_content.content | b64decode"
        fail_msg: "console=tty1 not found in boot parameters. Please add manually."
      when: false  # Warning only, don't fail

    - name: Verify serial console is set
      assert:
        that: "'console=ttyS0' in bootloader_content.content | b64decode"
        fail_msg: "Serial console not configured. Diagnostics may not be available."
      when: false  # Warning only, don't fail

#
# Systemd Quiet Configuration
#

- name: Create systemd system.conf.d directory
  file:
    path: /etc/systemd/system.conf.d
    state: directory
    mode: '0755'

- name: Configure systemd for quiet boot
  copy:
    dest: /etc/systemd/system.conf.d/quiet-boot.conf
    content: |
      # Loiterix Boot Splash - Systemd Quiet Configuration
      # Suppress systemd status messages during boot
      
      [Manager]
      # Show only critical messages on console
      LogLevel=warning
      
      # Don't show status messages during boot
      ShowStatus=no
      
      # Limit console messages
      # Commented out - handled by kernel loglevel parameter
      # DefaultStandardOutput=journal
      # DefaultStandardError=journal
    owner: root
    group: root
    mode: '0644'
  notify: Reload systemd daemon

#
# Getty Suppression
#

- name: Mask getty@tty1 to prevent login prompt during boot
  systemd:
    name: getty@tty1
    masked: yes
    enabled: no
  notify: Reload systemd daemon

- name: Configure autologin for application (if needed)
  block:
    - name: Create getty@tty1 override directory
      file:
        path: /etc/systemd/system/getty@tty1.service.d
        state: directory
        mode: '0755'

    - name: Configure autologin for loiterix user
      copy:
        dest: /etc/systemd/system/getty@tty1.service.d/autologin.conf
        content: |
          # Loiterix Boot Splash - Autologin Configuration
          # Automatically login loiterix user when getty is unmasked
          
          [Service]
          ExecStart=
          ExecStart=-/sbin/agetty --autologin {{ loiterix_user | default('loiterix') }} --noclear %I $TERM
          Type=idle
        owner: root
        group: root
        mode: '0644'
      notify: Reload systemd daemon
  when: loiterix_autologin | default(false)

#
# Optional: PSplash for Extended Splash
#

- name: Install PSplash (optional, for extended boot splash)
  apt:
    name: psplash
    state: present
    update_cache: yes
  when: loiterix_use_psplash | default(false)
  tags: psplash

- name: Deploy Loiterix PSplash assets
  block:
    - name: Create psplash directory
      file:
        path: /usr/share/loiterix/psplash
        state: directory
        mode: '0755'

    - name: Copy PSplash logo images
      copy:
        src: "{{ item }}"
        dest: "/usr/share/loiterix/psplash/{{ item | basename }}"
        owner: root
        group: root
        mode: '0644'
      loop:
        - files/psplash-loiterix-640x480.png
        - files/psplash-loiterix-800x600.png
        - files/psplash-loiterix-1024x768.png
        - files/psplash-loiterix-1920x1080.png
      when: loiterix_psplash_assets_available | default(false)

    - name: Configure PSplash systemd service
      copy:
        dest: /etc/systemd/system/psplash.service
        content: |
          # Loiterix Boot Splash - PSplash Service
          # Extended boot splash using PSplash
          
          [Unit]
          Description=Loiterix Boot Splash (PSplash)
          DefaultDependencies=no
          After=sysinit.target plymouth-quit.service
          Before=basic.target display-manager.service
          ConditionPathExists=/usr/bin/psplash
          
          [Service]
          Type=forking
          ExecStart=/usr/bin/psplash --angle 0 --no-console-switch
          ExecStop=/usr/bin/psplash-write "QUIT"
          RemainAfterExit=yes
          TimeoutSec=5
          
          [Install]
          WantedBy=sysinit.target
        owner: root
        group: root
        mode: '0644'
      notify: Reload systemd daemon

    - name: Enable PSplash service
      systemd:
        name: psplash
        enabled: yes
        daemon_reload: yes
  when: loiterix_use_psplash | default(false)
  tags: psplash

#
# Application Integration
#

- name: Configure application to dismiss splash
  block:
    - name: Add splash dismissal to application service
      blockinfile:
        path: /etc/systemd/system/{{ loiterix_app_service }}.service
        insertafter: '^\[Service\]'
        marker: "# {mark} LOITERIX BOOT SPLASH MANAGED BLOCK"
        block: |
          # Dismiss PSplash when application starts
          ExecStartPre=-/bin/sh -c 'if [ -e /usr/bin/psplash-write ]; then /usr/bin/psplash-write "QUIT"; sleep 0.2; fi'
          
          # Unmask getty after application is running (optional)
          # ExecStartPost=-/bin/systemctl unmask getty@tty1
      notify: Reload systemd daemon
  when:
    - loiterix_use_psplash | default(false)
    - loiterix_app_service is defined

#
# Logging and Diagnostics
#

- name: Ensure serial console is accessible
  block:
    - name: Configure serial console getty
      systemd:
        name: serial-getty@ttyS0
        enabled: yes

    - name: Verify serial console is working
      shell: |
        if [ -c /dev/ttyS0 ]; then
          echo "Serial console /dev/ttyS0 is available"
          exit 0
        else
          echo "Warning: Serial console /dev/ttyS0 not found"
          exit 1
        fi
      register: serial_check
      changed_when: false
      failed_when: false

    - name: Display serial console status
      debug:
        msg: "{{ serial_check.stdout }}"

- name: Configure journal for boot log preservation
  lineinfile:
    path: /etc/systemd/journald.conf
    regexp: '^#?Storage='
    line: 'Storage=persistent'
  notify: Restart journald

#
# Validation
#

- name: Validate boot splash configuration
  block:
    - name: Check boot parameters
      shell: cat {{ bootloader_config }} | grep -E "(quiet|loglevel)"
      register: boot_params_check
      changed_when: false
      failed_when: false

    - name: Check systemd configuration
      shell: grep -E "(LogLevel|ShowStatus)" /etc/systemd/system.conf.d/quiet-boot.conf
      register: systemd_check
      changed_when: false
      failed_when: false

    - name: Check getty status
      shell: systemctl is-masked getty@tty1
      register: getty_check
      changed_when: false
      failed_when: false

    - name: Display configuration summary
      debug:
        msg: |
          Boot Splash Configuration Summary:
          ==================================
          Boot parameters: {{ 'OK' if boot_params_check.rc == 0 else 'NOT CONFIGURED' }}
          Systemd quiet mode: {{ 'OK' if systemd_check.rc == 0 else 'NOT CONFIGURED' }}
          Getty masked: {{ 'YES' if getty_check.rc == 0 else 'NO' }}
          PSplash: {{ 'ENABLED' if loiterix_use_psplash | default(false) else 'DISABLED' }}
          Serial console: {{ 'OK' if serial_check.rc == 0 else 'NOT AVAILABLE' }}
          
          Next steps:
          1. Review boot configuration in {{ bootloader_config }}
          2. Reboot to test boot splash
          3. Monitor serial console (screen /dev/ttyUSB0 115200) during boot
          4. Verify logs after boot: journalctl -b

# Handlers
handlers:
  - name: Reload systemd daemon
    systemd:
      daemon_reload: yes

  - name: Reboot required
    debug:
      msg: "NOTICE: Reboot required to apply boot parameter changes"

  - name: Restart journald
    systemd:
      name: systemd-journald
      state: restarted
```

### 2. Create PSplash Asset Files (Optional)

If using PSplash, copy the pre-generated logo images to the ansible files directory:

**Directory**: `ansible/files/`

Files to create (from kernel repo converted assets):
- `psplash-loiterix-640x480.png`
- `psplash-loiterix-800x600.png`
- `psplash-loiterix-1024x768.png`
- `psplash-loiterix-1920x1080.png`

These were generated from the original Figma export and are available in the kernel repository at `/tmp/splash-work/psplash-*.png`.

### 3. Integrate into Main Playbook

**File**: `ansible/site.yml` (or main playbook)

```yaml
---
- name: Configure Loiterix Platform
  hosts: loiterix_devices
  become: yes
  
  vars:
    # Boot splash configuration
    loiterix_user: "loiterix"
    loiterix_autologin: false          # Set true for kiosk mode
    loiterix_use_psplash: false        # Set true for extended splash
    loiterix_psplash_assets_available: false  # Set true when assets are deployed
    loiterix_app_service: "loiterix-app"  # Your application service name

  tasks:
    # ... existing tasks ...
    
    - name: Configure boot splash
      import_tasks: tasks/boot-splash.yml
      tags: [boot-splash, platform]
    
    # ... remaining tasks ...
```

### 4. Deploy to Device

```bash
# From loiterix-platform repository
cd ansible/

# Deploy to specific device
ansible-playbook -i inventory site.yml \
  --limit target-device \
  --tags boot-splash

# Deploy to all devices
ansible-playbook -i inventory site.yml \
  --tags platform

# With custom variables
ansible-playbook -i inventory site.yml \
  --tags boot-splash \
  -e "loiterix_use_psplash=true" \
  -e "loiterix_autologin=true"
```

## Variables Reference

### Required Variables

None - uses sensible defaults

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `loiterix_user` | `loiterix` | Username for autologin (if enabled) |
| `loiterix_autologin` | `false` | Enable automatic login to application user |
| `loiterix_use_psplash` | `false` | Install and enable PSplash for extended splash |
| `loiterix_psplash_assets_available` | `false` | PSplash image assets are deployed |
| `loiterix_app_service` | `loiterix-app` | Systemd service name for main application |

### Example Inventory

```ini
# inventory/hosts
[loiterix_devices]
device-001 ansible_host=192.168.1.101
device-002 ansible_host=192.168.1.102

[loiterix_devices:vars]
ansible_user=ubuntu
ansible_become=yes
loiterix_user=loiterix
loiterix_use_psplash=false
loiterix_autologin=true
```

## Testing Procedure

### 1. Pre-deployment Checks

```bash
# Verify kernel has boot splash support
ssh target-device "zcat /proc/config.gz | grep -E 'CONFIG_LOGO|CONFIG_FB'"

# Should show:
# CONFIG_LOGO=y
# CONFIG_LOGO_LINUX_CLUT224=y
# CONFIG_FB=y
# CONFIG_FRAMEBUFFER_CONSOLE=y
```

### 2. Deploy Configuration

```bash
ansible-playbook -i inventory site.yml --limit target-device --tags boot-splash
```

### 3. Verify Configuration

```bash
# Check boot parameters
ssh target-device "cat /boot/extlinux/extlinux.conf | grep quiet"

# Check systemd config
ssh target-device "cat /etc/systemd/system.conf.d/quiet-boot.conf"

# Check getty status
ssh target-device "systemctl is-masked getty@tty1"
```

### 4. Test Boot

```bash
# Connect serial console FIRST (to see all output)
screen /dev/ttyUSB0 115200

# Then reboot device
ssh target-device "sudo reboot"

# Observe:
# - Serial console: Full kernel + systemd output
# - Display: Loiterix logo, minimal messages
```

### 5. Post-boot Verification

```bash
# Check boot log
ssh target-device "journalctl -b | head -50"

# Verify serial console worked
ssh target-device "journalctl -b | grep ttyS0"

# Check for boot errors
ssh target-device "journalctl -b -p err"
```

## Troubleshooting

### Boot Parameters Not Applied

**Symptom**: Kernel messages still visible on display

**Fix**:
```bash
# Verify bootloader config
cat /boot/extlinux/extlinux.conf

# Should contain:
# APPEND ... quiet loglevel=3 vt.global_cursor_default=0

# If missing, add manually:
sudo nano /boot/extlinux/extlinux.conf

# Then reboot
sudo reboot
```

### Getty Still Appearing

**Symptom**: Login prompt appears during or after boot

**Fix**:
```bash
# Verify getty is masked
systemctl is-masked getty@tty1
# Should output: masked

# If not masked:
sudo systemctl mask getty@tty1
sudo systemctl stop getty@tty1
```

### Systemd Messages Visible

**Symptom**: Systemd status messages visible during boot

**Fix**:
```bash
# Check systemd config
cat /etc/systemd/system.conf.d/quiet-boot.conf

# Should contain:
# ShowStatus=no
# LogLevel=warning

# If not, create file and reload:
sudo systemctl daemon-reload
sudo reboot
```

### PSplash Not Starting

**Symptom**: PSplash service fails to start

**Fix**:
```bash
# Check service status
systemctl status psplash

# Check logs
journalctl -u psplash

# Verify psplash binary exists
which psplash

# Test manually
sudo psplash &
# (Display should show splash)
sudo psplash-write "QUIT"
```

### Serial Console Not Working

**Symptom**: No output on serial console during boot

**Check**:
```bash
# Verify serial device exists
ls -l /dev/ttyS0

# Check boot parameters include serial console
cat /proc/cmdline | grep ttyS0
# Should show: console=ttyS0,115200n8

# Check serial getty is enabled
systemctl status serial-getty@ttyS0
```

**Physical checks**:
- Verify USB-to-serial adapter connected
- Check TX/RX pins orientation
- Try different serial device (ttyS1, ttyUSB0)
- Verify baud rate (115200)

## Maintenance

### Disabling Boot Splash (Debug Mode)

Temporarily disable for debugging:

```bash
# Remove boot splash tag from getty mask
sudo systemctl unmask getty@tty1

# Or remove quiet from boot parameters
sudo nano /boot/extlinux/extlinux.conf
# Remove: quiet loglevel=3 vt.global_cursor_default=0

sudo reboot
```

### Re-enabling Boot Splash

```bash
# Re-mask getty
sudo systemctl mask getty@tty1

# Restore boot parameters
sudo nano /boot/extlinux/extlinux.conf
# Add: quiet loglevel=3 vt.global_cursor_default=0

sudo reboot
```

### Updating PSplash Assets

```bash
# Copy new assets
scp psplash-*.png target-device:/usr/share/loiterix/psplash/

# Restart PSplash
ssh target-device "sudo systemctl restart psplash"
```

## Integration with Application

### Application Service Requirements

Your application service should:

1. **Start after systemd initialization**
   ```ini
   [Unit]
   After=multi-user.target
   ```

2. **Dismiss PSplash** (if used)
   ```ini
   [Service]
   ExecStartPre=-/bin/sh -c 'if [ -e /usr/bin/psplash-write ]; then /usr/bin/psplash-write "QUIT"; fi'
   ```

3. **Take over framebuffer or display**
   - Application should open `/dev/fb0` or use DRM/KMS
   - Or start X11/Wayland session

4. **Optional: Unmask getty** (for maintenance access)
   ```ini
   [Service]
   ExecStartPost=-/bin/systemctl unmask getty@tty1
   ```

### Example Application Service

**File**: `/etc/systemd/system/loiterix-app.service`

```ini
[Unit]
Description=Loiterix Application
After=multi-user.target network.target
Wants=network.target

[Service]
Type=simple
User=loiterix
Group=loiterix
WorkingDirectory=/opt/loiterix
Environment="DISPLAY=:0"
Environment="FRAMEBUFFER=/dev/fb0"

# Dismiss PSplash before starting
ExecStartPre=-/bin/sh -c 'if [ -e /usr/bin/psplash-write ]; then /usr/bin/psplash-write "QUIT"; sleep 0.2; fi'

# Start application
ExecStart=/opt/loiterix/bin/loiterix-app

# Enable getty for maintenance access after app starts
ExecStartPost=-/bin/systemctl unmask getty@tty1

# Restart on failure
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

## Summary Checklist

- [ ] Create `ansible/tasks/boot-splash.yml` with userspace configuration
- [ ] Optional: Copy PSplash assets to `ansible/files/`
- [ ] Update main playbook to include boot-splash tasks
- [ ] Set appropriate variables for your environment
- [ ] Deploy to test device
- [ ] Verify with serial console connected
- [ ] Test boot, observe splash on display
- [ ] Verify serial console shows full output
- [ ] Check boot logs via journalctl
- [ ] Test debug mode (remove quiet parameter)
- [ ] Integrate with application service
- [ ] Deploy to production devices

## References

- Kernel implementation: `loiterix-linux-aw2511` repository, `docs/boot-splash.md`
- PSplash documentation: https://git.yoctoproject.org/psplash/
- Systemd documentation: https://www.freedesktop.org/software/systemd/man/systemd.html
- Serial console setup: `docs/boot-splash.md` in kernel repository

---

**Status**: Ready for implementation  
**Dependencies**: Kernel package with boot splash patch installed  
**Testing**: Required on actual hardware with display and serial console
