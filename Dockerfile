FROM linuxserver/code-server:4.101.2

RUN sudo apt-get update && apt-get install -y software-properties-common && sudo add-apt-repository ppa:deadsnakes/ppa && apt-get install -y python3 python3-pip && pip3 install ray[default] debugpy --break-system-packages

RUN mkdir -p /config/extensions \
    && curl -L -o /config/extensions/ms-python.python.vsix https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-python/vsextensions/python/2025.10.0/vspackage \
    && curl -L -o /config/extensions/ms-python.debugpy.vsix https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-python/vsextensions/debugpy/2025.10.0/vspackage \
    && curl -L -o /config/extensions/anyscalecompute.ray-distributed-debugger.vsix https://marketplace.visualstudio.com/_apis/public/gallery/publishers/anyscalecompute/vsextensions/ray-distributed-debugger/0.1.4/vspackage \
    && /app/code-server/bin/code-server --extensions-dir /config/extensions --install-extension ms-python.python \
    && /app/code-server/bin/code-server --extensions-dir /config/extensions --install-extension ms-python.debugpy \
    && /app/code-server/bin/code-server --extensions-dir /config/extensions --install-extension anyscalecompute.ray-distributed-debugger
