# Start with the base Ubuntu 22.04 image
FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# --- Part 1: Setting up the Ubuntu Environment ---

# Update package lists and install necessary tools
RUN apt-get update && apt-get install -y \
    tmate \
    openssh-server \
    openssh-client \
    systemd \
    systemd-sysv \
    dbus \
    dbus-user-session \
    curl \
    ufw \
    net-tools \
    iproute2 \
    hostname \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH to allow root login
RUN sed -i 's/^#\\?\\s*PermitRootLogin\\s\\+.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# Set the root password to 'root'
RUN echo 'root:root' | chpasswd

# Prevent services from starting automatically on installation
RUN printf '#!/bin/sh\\nexit 0' > /usr/sbin/policy-rc.d

# Enable necessary services to start on boot
RUN printf "systemctl start systemd-logind\n" >> /etc/profile
RUN ufw allow 80 && ufw allow 443

# --- Part 2: Setting up the Python Bot ---

# Install Python and pip
RUN apt-get update && apt-get install -y python3 python3-pip && rm -rf /var/lib/apt/lists/*

# Set the working directory for the bot
WORKDIR /app

# Copy and install Python dependencies
# This is done first to take advantage of Docker's layer caching
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy the rest of your bot's code into the container
COPY . .

# --- Final Configuration ---

# This command now needs to start the system services AND your bot.
# We will create a small script to do this.
RUN echo '#!/bin/bash\n\
# Start the system services in the background\n\
/sbin/init &\n\
# Wait a moment for services to come up\n\
sleep 5\n\
# Start the Python bot in the foreground\n\
echo "Starting Python bot..."\n\
python3 bot.py\n' > /app/start.sh

# Make the script executable
RUN chmod +x /app/start.sh

# Set the entrypoint to our new start script
CMD ["/app/start.sh"]
