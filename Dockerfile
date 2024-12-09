# Stage 1: Build stage
FROM python:3.11-slim AS build

## Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
# setup python virtual environment
ENV PATH="/opt/venv/bin:$PATH"

# Set a working directory for building
WORKDIR /opt/PDBCharges

# Install system dependencies for building
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    wget \
    curl \
    gfortran \
    git \
    libopenblas-dev \
    liblapack-dev \
    libeigen3-dev \
    libx11-dev \
    libglu1-mesa-dev \
    libxi-dev \
    libxrandr-dev \
    libxcursor-dev \
    libxtst-dev \
    zlib1g-dev \
    openbabel=3.1.1+dfsg-9+b3

# Set up python virtual environment
RUN python3 -m venv /opt/venv

# Install xtb 6.6.1
RUN curl -L https://github.com/grimme-lab/xtb/releases/download/v6.6.1/xtb-6.6.1-source.tar.xz | tar xJ \
    && cd xtb-6.6.1 \
    && mkdir build && cd build \
    && cmake .. \
    && make -j$(nproc) \
    && make install \
    && cd ../.. && rm -rf xtb-6.6.1

# Install Python dependencies
RUN pip install --no-cache-dir \
    dimorphite_dl==1.3.2 \
    hydride==1.2.3 \
    biopython==1.84 \
    numpy==1.26.4 \
    biotite==1.0.1 \
    gemmi==0.6.6 \
    rdkit==2023.09.6 \
    moleculekit==1.9.15 \
    pdb2pqr==3.6.1 \
    openmm==8.2.0 \
    && python3 

# Install pdbfixer
RUN git clone https://github.com/openmm/pdbfixer.git /opt/pdbfixer \
    && cd /opt/pdbfixer \
    && git config --global advice.detachedHead false \
    && git checkout c83d125f445d3cea414203d48e4438c6033aaec6 \
    && pip install .

## Get sources
COPY calculate_charges_workflow.py .
COPY phases phases
COPY docker docker
# Copy the custom preparation.py script from moleculekit lib
RUN python3 docker/edit_moleculekit.py /opt/venv/lib/python3.11/site-packages/moleculekit/tools/preparation.py

### Stage 2: Runtime stage
FROM python:3.11-slim

## Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/opt/PDBCharges:/home/user/.local/bin:${PATH}"
# Use prepared python environment
ENV PATH="/opt/venv/bin:$PATH"

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    nano \
    wget \
    openbabel=3.1.1+dfsg-9+b3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Get prepared python environment and other artefacts from build
COPY --from=build /opt/venv /opt/venv
COPY --from=build /opt/PDBCharges /opt/PDBCharges

# Set working directory
WORKDIR /opt/PDBCharges

# Create a non-root user and change ownership
RUN useradd --create-home --shell /bin/bash user \
    && chown -R user:user /opt \
    && chmod u+x calculate_charges_workflow.py

# Switch to the non-root user
USER user

# Set default command
CMD ["python3", "calculate_charges_workflow.py"]