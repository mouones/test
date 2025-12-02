[Unit]
Description=${app_name} Application (${framework_name})
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${working_dir}
Environment="PATH=/opt/app/venv/bin:/root/.cargo/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/bin/bash -c '${exec_start}'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
