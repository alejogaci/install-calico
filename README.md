# Install Calico on Amazon EKS

## Overview
This script installs [Calico](https://projectcalico.docs.tigera.io/) as the networking solution for your Amazon EKS cluster. It should be executed from a bastion host or a server that has access to the Kubernetes API server.

## Prerequisites
- An Amazon EKS cluster up and running.
- A bastion host or a server with network access to the API server.
- `kubectl` installed and configured to interact with the EKS cluster.
- Execution permissions for the script (`install_calico.sh`).

## Installation

### 1. Clone the repository
```sh
git clone https://github.com/your-repo/install-calico.git
cd install-calico
```

### 2. Make the script executable
```sh
chmod +x install_calico.sh
```

### 3. Run the script
```sh
./install_calico.sh
```

## Verification
After the installation, you can verify that Calico is running properly by checking the pods in the `calico-system` namespace:
```sh
kubectl get pods -n calico-system
```

If everything is set up correctly, you should see running pods related to Calico.

## Troubleshooting
If you encounter any issues:
- Check the logs of the Calico pods:
  ```sh
  kubectl logs -n calico-system -l k8s-app=calico-node
  ```
- Ensure your server has network access to the API server.
- Verify that `kubectl` is configured correctly and can interact with the EKS cluster.

## License
This project is licensed under the MIT License.

