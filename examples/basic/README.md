# Basic usage

This example shows a basic usage of the Nebuly's platform GCP Terraform module.


## Platform installation

After running terraform apply, follow the steps below to install the Nebuly platform on the infrastructure provisioned by this module.

### 1. Connect to the GKE Cluster

For connecting to the created GKE cluster, you can follow the steps below. For more information,
refer to the [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl).

- Install the [GCloud CLI](https://cloud.google.com/sdk/docs/install-sdk).

- Install [kubectl](https://kubernetes.io/docs/reference/kubectl/):

```shell
gcloud components install kubectl
```

- Install the Install the gke-gcloud-auth-plugin:

```shell
gcloud components install gke-gcloud-auth-plugin
```

- Fetch the command for retrieving the credentials from the module outputs:

```shell
terraform output gke_cluster_get_credentials
```

- Run the command you got from the previous step

### 2. Create image pull secret

The auto-generated Helm values use the name defined in the k8s_image_pull_secret_name input variable for the Image Pull Secret. If you prefer a custom name, update either the Terraform variable or your Helm values accordingly.
Create a Kubernetes [Image Pull Secret](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/) for
authenticating with your Docker registry and pulling the Nebuly Docker images.

### 3. Bootstrap GKE cluster

Install the bootstrap Helm chart to set up all the dependencies required for installing the Nebuly Platform Helm chart on GKE.

Refer to the [chart documentation](https://github.com/nebuly-ai/helm-charts/tree/main/bootstrap-gcp) for all the configuration details.

```shell
helm install nebuly-bootstrap oci://ghcr.io/nebuly-ai/helm-charts/bootstrap-gcp \
  --namespace nebuly-bootstrap \
  --create-namespace
```

### 4. Create Secret Provider Class

Create a Secret Provider Class to allow GKE to fetch credentials from the provisioned Key Vault.

- Get the Secret Provider Class YAML definition from the Terraform module outputs:

  ```shell
  terraform output secret_provider_class
  ```

- Copy the output of the command into a file named secret-provider-class.yaml.

- Run the following commands to install Nebuly in the Kubernetes namespace nebuly:

  ```shell
  kubectl create ns nebuly
  kubectl apply --server-side -f secret-provider-class.yaml
  ```

### 5. Install nebuly-platform chart

Retrieve the auto-generated values from the Terraform outputs and save them to a file named `values.yaml`:

```shell
terraform output helm_values
```

Install the Nebuly Platform Helm chart.
Refer to the [chart documentation](https://github.com/nebuly-ai/helm-charts/tree/main/nebuly-platform) for detailed configuration options.

```shell
helm install <your-release-name> oci://ghcr.io/nebuly-ai/helm-charts/nebuly-platform \
  --namespace nebuly \
  -f values.yaml \
  --timeout 45m
```

> ℹ️ During the initial installation of the chart, all required Nebuly LLMs are uploaded to your model registry.
> This process can take approximately 5 minutes. If the helm install command appears to be stuck, don't worry: it's simply waiting for the upload to finish.
