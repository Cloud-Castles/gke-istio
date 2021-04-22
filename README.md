# GKE with istio deployment

## Configuration

* Choose (or create) a project in GCP to which you will deploy
* Generate a service account in GCP with owner permissions, or use existing, and export SA credentials json

* Run:
`export GOOGLE_APPLICATION_CREDENTIALS=<path-to-credentials-file>.json`

* Install terraform 14
(install guide [here](https://learn.hashicorp.com/tutorials/terraform/install-cli))
(Binary download [here](https://www.terraform.io/downloads.html))

* Create `.auto.tfvars` file and specify it with name of a project like in a `terraform.tfvars.sample` file


## Deployment

* Run
`terraform plan`
* If plan returns successfully, run
`terraform apply`

In the terraform outputs you will see the website URL
