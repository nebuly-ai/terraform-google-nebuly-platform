# Microsoft Entra SSO Example

Nebuly supports several authentication methods.
This example shows how to use [Microsoft Entra SSO](https://www.microsoft.com/en-us/security/business/identity-access/microsoft-entra-single-sign-on) to authenticate users.

## Prerequisites

### Step 1: Register a Microsoft Entra Application

1. Sign in to the [Azure Portal](https://portal.azure.com/).
2. In the left-hand menu, select **Microsoft Entra ID**.
3. Under the **Manage** section, click **App registrations** > **New registration**.
4. Fill out the registration form:
   - **Name**: Choose a meaningful name (e.g., `Nebuly SSO`).
   - **Redirect URI**:
     - Choose **Web** as the platform.
     - `https://<platform_domain>/backend/auth/oauth/microsoft/callback`, where `<platform_domain>` is
       the value you provided for the Terraform variable `platform_domain`.
5. Click **Register**.
6. After registration, go to **Certificates & secrets** from the sidebar.
7. Click **+ New client secret** and configure:
   - **Description**: `Nebuly OAuth2`
   - **Expires**: `24 months`
8. Save and securely store the following values:
   - **Application (client) ID**
   - **Client secret (value)**

### Step 2: Define Application Roles

1. Open the Entra Application you created.
2. From the sidebar, go to **App roles**.
3. Click **+ Create app role** and define the following roles:

- **Role: Viewer**
  - **Display name**: `Viewer`
  - **Allowed member types**: `Users/Groups`
  - **Value**: `viewer`
  - **Description**: `Users with read-only access to Nebuly`

- **Role: Member**
  - **Display name**: `Member`
  - **Allowed member types**: `Users/Groups`
  - **Value**: `member`
  - **Description**: `Users with standard access to Nebuly`

- **Role: Admin**
  - **Display name**: `Admin`
  - **Allowed member types**: `Users/Groups`
  - **Value**: `admin`
  - **Description**: `Users with admin access to Nebuly`

### Step 3: Assign Users or Groups to Roles

To grant access to the Nebuly platform:

1. In the Azure Portal, go to **Microsoft Entra ID** > **Enterprise applications**.
2. Select the application you created.
3. In the left-hand menu, click **Properties**
   - Set **Assignment required?** to **Yes**
4. In the left-hand menu, click **Users and groups**.
5. Click **+ Add user/group**.
6. Select users or groups, and assign them to one of the roles you created (`Viewer`, `Member`, or `Admin`).
7. Confirm and save your changes.

## Terraform configuration

To enable Microsoft Entra SSO authentication in Nebuly, you need to provide the following Terraform variables:

```hcl
microsoft_sso = {
    client_id     = "<your-app-client-id>"
    client_secret = "<your-app-client-secret>"
    issuer        = "<your-microsoft-tenant-id>"
}
```

The Terraform module will automatically generate the reuired Helm values and secret provider class
for the Microsoft Entra SSO integration.

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
