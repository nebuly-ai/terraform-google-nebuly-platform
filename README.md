# Nebuly Platform (GCP)

Terraform module for provisioning Nebuly Platform resources on GCP.

Available on [Terraform Registry](https://registry.terraform.io/modules/nebuly-ai/nebuly-platform/google/latest).

## Prerequisites

### Nebuly Credentials

Before using this Terraform module, ensure that you have your Nebuly credentials ready. 
These credentials are necessary to activate your installation and should be provided as input via the `nebuly_credentials` input.

### Required GCP APIs

Before using this Terraform module, ensure that the following GCP APIs are enabled in your Google Cloud project:

- [sqladmin.googleapis.com](https://cloud.google.com/sql/docs/mysql/admin-api)
- [servicenetworking.googleapis.com](https://cloud.google.com/service-infrastructure/docs/service-networking/getting-started)
- [cloudresourcemanager.googleapis.com](https://cloud.google.com/resource-manager/reference/rest)
- [container.googleapis.com](https://cloud.google.com/kubernetes-engine/docs/reference/rest)
- [secretmanager.googleapis.com](https://cloud.google.com/secret-manager/docs/reference/rest)

You can enable the APIs using either the GCP Console or the gcloud CLI, as explained in the [GCP Documentation](https://cloud.google.com/endpoints/docs/openapi/enable-api#gcloud).

### Required GCP Quotas

Ensure that your GCP project has the necessary quotas for the following resources over the regions you plan to deploy Nebuly:

- **Name**: GPUs (all regions) 
  
  **Min Value**: 2
- **Name**: NVIDIA L4 GPUs 
  
  **Min Value**: 1

For more information on how to check and increase quotas, refer to the [GCP Documentation](https://cloud.google.com/docs/quotas/view-manage).
  

## Quickstart
To get started with installing Nebuly on GCP, follow the steps below.
This guide uses the standard configuration provided by the official Nebuly Helm chart.

For advanced configurations or support, feel free to reach out via the Nebuly Slack channel or email us at [support@nebuly.ai](mailto:support@nebuly.ai).

Additional examples are available:

* [Basic](./examples/basic/README.md): Minimal setup with default settings.
* [Microsoft SSO](./examples/microsoft-sso/README.md): Setup with Microsoft SSO authentication.

### 1. Terraform setup

Import Nebuly into your Terraform root module, provide the necessary variables, and apply the changes.

For configuration examples, you can refer to the [Examples](#examples). 

Once the Terraform changes are applied, proceed with the next steps to deploy Nebuly on the provisioned Google Kubernetes Engine (GKE) cluster.

### 2. Connect to the GKE Cluster 

For connecting to the created GKE cluster, you can follow the steps below. For more information, 
refer to the [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl).

* Install the [GCloud CLI](https://cloud.google.com/sdk/docs/install-sdk).

* Install [kubectl](https://kubernetes.io/docs/reference/kubectl/):
```shell
gcloud components install kubectl
```

* Install the Install the gke-gcloud-auth-plugin:
```shell
gcloud components install gke-gcloud-auth-plugin
```

* Fetch the command for retrieving the credentials from the module outputs:

```shell
terraform output gke_cluster_get_credentials
```

* Run the command you got from the previous step

### 3. Create image pull secret

The auto-generated Helm values use the name defined in the k8s_image_pull_secret_name input variable for the Image Pull Secret. If you prefer a custom name, update either the Terraform variable or your Helm values accordingly.
Create a Kubernetes [Image Pull Secret](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/) for 
authenticating with your Docker registry and pulling the Nebuly Docker images.

Example:

```shell
kubectl create secret generic nebuly-docker-pull \
  -n nebuly \    
  --from-file=.dockerconfigjson=dockerconfig.json \
  --type=kubernetes.io/dockerconfigjson
```

### 4. Bootstrap GKE cluster

Install the bootstrap Helm chart to set up all the dependencies required for installing the Nebuly Platform Helm chart on GKE.

Refer to the [chart documentation](https://github.com/nebuly-ai/helm-charts/tree/main/bootstrap-gcp) for all the configuration details.

```shell
helm install nebuly-bootstrap oci://ghcr.io/nebuly-ai/helm-charts/bootstrap-gcp \
  --namespace nebuly-bootstrap \
  --create-namespace 
```


### 5. Create Secret Provider Class
Create a Secret Provider Class to allow GKE to fetch credentials from the provisioned Key Vault.

* Get the Secret Provider Class YAML definition from the Terraform module outputs:
  ```shell
  terraform output secret_provider_class
  ```

* Copy the output of the command into a file named secret-provider-class.yaml.

* Run the following commands to install Nebuly in the Kubernetes namespace nebuly:

  ```shell
  kubectl create ns nebuly
  kubectl apply --server-side -f secret-provider-class.yaml
  ```


### 6. Install nebuly-platform chart

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

> ℹ️  During the initial installation of the chart, all required Nebuly LLMs are uploaded to your model registry. 
> This process can take approximately 5 minutes. If the helm install command appears to be stuck, don't worry: it's simply waiting for the upload to finish.

### 7. Access Nebuly

Retrieve the external Load Balancer IP address to access the Nebuly Platform:

```shell
kubectl get svc -n nebuly-bootstrap -o jsonpath='{range .items[?(@.status.loadBalancer.ingress)]}{.status.loadBalancer.ingress[0].ip}{"\n"}{end}'
```

You can then register a DNS A record pointing to the Load Balancer IP address to access Nebuly via the custom domain you provided 
in the input variable `platform_domain`.


## Examples

You can find examples of code that uses this Terraform module in the [examples](./examples) directory.




## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | ~>6.3.0 |
| <a name="provider_random"></a> [random](#provider\_random) | ~>3.6 |
| <a name="provider_tls"></a> [tls](#provider\_tls) | ~>4.0 |


## Outputs

| Name | Description |
|------|-------------|
| <a name="output_gke_cluster_get_credentials"></a> [gke\_cluster\_get\_credentials](#output\_gke\_cluster\_get\_credentials) | The command for connecting with the provisioned GKE cluster. |
| <a name="output_helm_values"></a> [helm\_values](#output\_helm\_values) | The `values.yaml` file for installing Nebuly with Helm.<br/><br/>  The default standard configuration is used, which uses Nginx as ingress controller and exposes the application to the Internet. This configuration can be customized according to specific needs. |
| <a name="output_secret_provider_class"></a> [secret\_provider\_class](#output\_secret\_provider\_class) | The `secret-provider-class.yaml` file to make Kubernetes reference the secrets stored in the Key Vault. |


## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_gke_cluster_admin_users"></a> [gke\_cluster\_admin\_users](#input\_gke\_cluster\_admin\_users) | The list of email addresses of the users who will have admin access to the GKE cluster. | `set(string)` | n/a | yes |
| <a name="input_gke_delete_protection"></a> [gke\_delete\_protection](#input\_gke\_delete\_protection) | Whether the GKE Cluster should have delete protection enabled. | `bool` | `true` | no |
| <a name="input_gke_kubernetes_version"></a> [gke\_kubernetes\_version](#input\_gke\_kubernetes\_version) | The used Kubernetes version for the GKE cluster. | `string` | `"1.32.4"` | no |
| <a name="input_gke_nebuly_namespaces"></a> [gke\_nebuly\_namespaces](#input\_gke\_nebuly\_namespaces) | The namespaces used by Nebuly installation. Update this if you use custom namespaces in the Helm chart installation. | `set(string)` | <pre>[<br/>  "nebuly",<br/>  "nebuly-bootstrap"<br/>]</pre> | no |
| <a name="input_gke_node_pools"></a> [gke\_node\_pools](#input\_gke\_node\_pools) | The node Pools used by the GKE cluster. | <pre>map(object({<br/>    machine_type    = string<br/>    min_nodes       = number<br/>    max_nodes       = number<br/>    node_count      = number<br/>    resource_labels = optional(map(string), {})<br/>    disk_type       = optional(string, "pd-balanced")<br/>    disk_size_gb    = optional(number, 128)<br/>    node_locations  = optional(set(string), null)<br/>    preemptible     = optional(bool, false)<br/>    labels          = optional(map(string), {})<br/>    taints = optional(set(object({<br/>      key    = string<br/>      value  = string<br/>      effect = string<br/>    })), null)<br/>    guest_accelerator = optional(object({<br/>      type  = string<br/>      count = number<br/>    }), null)<br/>  }))</pre> | <pre>{<br/>  "gpu-primary": {<br/>    "guest_accelerator": {<br/>      "count": 1,<br/>      "type": "nvidia-l4"<br/>    },<br/>    "labels": {<br/>      "gke-no-default-nvidia-gpu-device-plugin": true,<br/>      "nebuly.com/accelerator": "nvidia-l4"<br/>    },<br/>    "machine_type": "g2-standard-8",<br/>    "max_nodes": 1,<br/>    "min_nodes": 0,<br/>    "node_count": null,<br/>    "resource_labels": {<br/>      "goog-gke-accelerator-type": "nvidia-l4",<br/>      "goog-gke-node-pool-provisioning-model": "on-demand"<br/>    }<br/>  },<br/>  "web-services": {<br/>    "machine_type": "n2-highmem-4",<br/>    "max_nodes": 1,<br/>    "min_nodes": 1,<br/>    "node_count": 1,<br/>    "resource_labels": {<br/>      "goog-gke-node-pool-provisioning-model": "on-demand"<br/>    }<br/>  }<br/>}</pre> | no |
| <a name="input_gke_service_account_name"></a> [gke\_service\_account\_name](#input\_gke\_service\_account\_name) | The name of the Kubernetes Service Account used by Nebuly installation. | `string` | `"nebuly"` | no |
| <a name="input_k8s_image_pull_secret_name"></a> [k8s\_image\_pull\_secret\_name](#input\_k8s\_image\_pull\_secret\_name) | The name of the Kubernetes Image Pull Secret to use. <br/>  This value will be used to auto-generate the values.yaml file for installing the Nebuly Platform Helm chart. | `string` | `"nebuly-docker-pull"` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Common labels that will be applied to all resources. | `map(string)` | `{}` | no |
| <a name="input_microsoft_sso"></a> [microsoft\_sso](#input\_microsoft\_sso) | Settings for configuring the Microsoft Entra SSO integration. | <pre>object({<br/>    tenant_id : string<br/>    client_id : string<br/>    client_secret : string<br/>  })</pre> | `null` | no |
| <a name="input_nebuly_credentials"></a> [nebuly\_credentials](#input\_nebuly\_credentials) | The credentials provided by Nebuly are required for activating your platform installation. <br/>  If you haven't received your credentials or have lost them, please contact support@nebuly.ai. | <pre>object({<br/>    client_id : string<br/>    client_secret : string<br/>  })</pre> | n/a | yes |
| <a name="input_network_cidr_blocks"></a> [network\_cidr\_blocks](#input\_network\_cidr\_blocks) | The CIDR blocks of the VPC network used by Nebuly.<br/><br/>  - primary: The primary CIDR block of the VPC network.<br/>  - secondary\_gke\_pods: The secondary CIDR block used by GKE for pods.<br/>  - secondary\_gke\_services: The secondary CIDR block used by GKE for services. | <pre>object({<br/>    primary : string<br/>    secondary_gke_pods : string<br/>    secondary_gke_services : string<br/>  })</pre> | <pre>{<br/>  "primary": "10.0.0.0/16",<br/>  "secondary_gke_pods": "10.4.0.0/16",<br/>  "secondary_gke_services": "10.6.0.0/16"<br/>}</pre> | no |
| <a name="input_openai_api_key"></a> [openai\_api\_key](#input\_openai\_api\_key) | The API Key used for authenticating with OpenAI. | `string` | n/a | yes |
| <a name="input_openai_endpoint"></a> [openai\_endpoint](#input\_openai\_endpoint) | The endpoint of the OpenAI API. | `string` | n/a | yes |
| <a name="input_openai_gpt4o_deployment_name"></a> [openai\_gpt4o\_deployment\_name](#input\_openai\_gpt4o\_deployment\_name) | The name of the deployment to use for the GPT-4o model. | `string` | n/a | yes |
| <a name="input_openai_translation_deployment_name"></a> [openai\_translation\_deployment\_name](#input\_openai\_translation\_deployment\_name) | The name of the deployment to use for enabling the translations feature. Recommended to use `gpt-4o-mini`.<br/>  Provide an empty string to disable the translations feature. | `string` | n/a | yes |
| <a name="input_platform_domain"></a> [platform\_domain](#input\_platform\_domain) | The domain on which the deployed Nebuly platform is made accessible. | `string` | n/a | yes |
| <a name="input_postgres_server_backup_configuration"></a> [postgres\_server\_backup\_configuration](#input\_postgres\_server\_backup\_configuration) | The backup settings of the PostgreSQL server. | <pre>object({<br/>    enabled                        = bool<br/>    point_in_time_recovery_enabled = bool<br/>    n_retained_backups             = number<br/>  })</pre> | <pre>{<br/>  "enabled": true,<br/>  "n_retained_backups": 14,<br/>  "point_in_time_recovery_enabled": true<br/>}</pre> | no |
| <a name="input_postgres_server_delete_protection"></a> [postgres\_server\_delete\_protection](#input\_postgres\_server\_delete\_protection) | Whether the PostgreSQL server should have delete protection enabled. | `bool` | `true` | no |
| <a name="input_postgres_server_disk_size"></a> [postgres\_server\_disk\_size](#input\_postgres\_server\_disk\_size) | The size of the disk in GB for the PostgreSQL server. | <pre>object({<br/>    initial = number<br/>    limit   = number<br/>  })</pre> | <pre>{<br/>  "initial": 16,<br/>  "limit": 1000<br/>}</pre> | no |
| <a name="input_postgres_server_edition"></a> [postgres\_server\_edition](#input\_postgres\_server\_edition) | The edition of the PostgreSQL server. Possible values are ENTERPRISE, ENTERPRISE\_PLUS. | `string` | `"ENTERPRISE"` | no |
| <a name="input_postgres_server_high_availability"></a> [postgres\_server\_high\_availability](#input\_postgres\_server\_high\_availability) | The high availability configuration for the PostgreSQL server. | <pre>object({<br/>    enabled : bool<br/>  })</pre> | <pre>{<br/>  "enabled": true<br/>}</pre> | no |
| <a name="input_postgres_server_maintenance_window"></a> [postgres\_server\_maintenance\_window](#input\_postgres\_server\_maintenance\_window) | Time window when the PostgreSQL server can automatically restart to apply updates. Specified in UTC time. | <pre>object({<br/>    day : string<br/>    hour : number<br/>  })</pre> | <pre>{<br/>  "day": "6",<br/>  "hour": 23<br/>}</pre> | no |
| <a name="input_postgres_server_tier"></a> [postgres\_server\_tier](#input\_postgres\_server\_tier) | The tier of the PostgreSQL server. Default value: 4 vCPU, 16GB memory. | `string` | `"db-n1-standard-4"` | no |
| <a name="input_region"></a> [region](#input\_region) | The region where the resources will be created | `string` | n/a | yes |
| <a name="input_resource_prefix"></a> [resource\_prefix](#input\_resource\_prefix) | The prefix that is used for generating resource names. | `string` | n/a | yes |

## Resources


- resource.google_compute_global_address.main (/terraform-docs/main.tf#43)
- resource.google_compute_network.main (/terraform-docs/main.tf#38)
- resource.google_compute_network_peering_routes_config.main (/terraform-docs/main.tf#73)
- resource.google_compute_subnetwork.main (/terraform-docs/main.tf#50)
- resource.google_container_cluster.main (/terraform-docs/main.tf#206)
- resource.google_container_node_pool.main (/terraform-docs/main.tf#254)
- resource.google_project_iam_binding.gke_cluster_admin (/terraform-docs/main.tf#341)
- resource.google_project_iam_member.gke_secret_accessors (/terraform-docs/main.tf#318)
- resource.google_secret_manager_secret.jwt_signing_key (/terraform-docs/main.tf#358)
- resource.google_secret_manager_secret.microsoft_sso_client_id (/terraform-docs/main.tf#410)
- resource.google_secret_manager_secret.microsoft_sso_client_secret (/terraform-docs/main.tf#426)
- resource.google_secret_manager_secret.nebuly_client_id (/terraform-docs/main.tf#384)
- resource.google_secret_manager_secret.nebuly_client_secret (/terraform-docs/main.tf#396)
- resource.google_secret_manager_secret.openai_api_key (/terraform-docs/main.tf#372)
- resource.google_secret_manager_secret.postgres_analytics_password (/terraform-docs/main.tf#150)
- resource.google_secret_manager_secret.postgres_analytics_username (/terraform-docs/main.tf#138)
- resource.google_secret_manager_secret.postgres_auth_password (/terraform-docs/main.tf#191)
- resource.google_secret_manager_secret.postgres_auth_username (/terraform-docs/main.tf#179)
- resource.google_secret_manager_secret_version.jwt_signing_key (/terraform-docs/main.tf#366)
- resource.google_secret_manager_secret_version.microsoft_sso_client_id (/terraform-docs/main.tf#420)
- resource.google_secret_manager_secret_version.microsoft_sso_client_secret (/terraform-docs/main.tf#436)
- resource.google_secret_manager_secret_version.nebuly_client_id (/terraform-docs/main.tf#392)
- resource.google_secret_manager_secret_version.nebuly_client_secret (/terraform-docs/main.tf#404)
- resource.google_secret_manager_secret_version.openai_api_key (/terraform-docs/main.tf#380)
- resource.google_secret_manager_secret_version.postgres_analytics_password (/terraform-docs/main.tf#158)
- resource.google_secret_manager_secret_version.postgres_analytics_username (/terraform-docs/main.tf#146)
- resource.google_secret_manager_secret_version.postgres_auth_password (/terraform-docs/main.tf#199)
- resource.google_secret_manager_secret_version.postgres_auth_username (/terraform-docs/main.tf#187)
- resource.google_service_account.gke_node_pool (/terraform-docs/main.tf#250)
- resource.google_service_networking_connection.main (/terraform-docs/main.tf#68)
- resource.google_sql_database.analytics (/terraform-docs/main.tf#122)
- resource.google_sql_database.auth (/terraform-docs/main.tf#163)
- resource.google_sql_database_instance.main (/terraform-docs/main.tf#82)
- resource.google_sql_user.analytics (/terraform-docs/main.tf#133)
- resource.google_sql_user.auth (/terraform-docs/main.tf#174)
- resource.google_storage_bucket.main (/terraform-docs/main.tf#445)
- resource.google_storage_bucket_iam_binding.gke_storage_object_user (/terraform-docs/main.tf#329)
- resource.random_password.analytics (/terraform-docs/main.tf#128)
- resource.random_password.auth (/terraform-docs/main.tf#169)
- resource.tls_private_key.jwt_signing_key (/terraform-docs/main.tf#354)
- data source.google_compute_zones.available (/terraform-docs/main.tf#23)
- data source.google_container_engine_versions.main (/terraform-docs/main.tf#24)
- data source.google_project.current (/terraform-docs/main.tf#22)
