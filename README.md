# Damson Cloud GCP Cloud Foundations: GCP project

Terraform module of the Damson Cloud GCP Cloud Foundations creating a single workload project:

* the project in its environment's folder, with a generated `<environment short name>-<name>-<suffix>` ID, its APIs, labels and essential contacts,
* the project's membership of the Observability project's metrics scope,
* the project's budget, alerting the billing administrators,
* optionally, the [billing disabler](https://github.com/damsoncloud/gcp.billing-disabler) deployed by cf-observability: the budget's notifications are published to its topic
  and its service account gets its roles on the project,
* optionally, for a project in the production or common environment, its membership of the VPC Service Controls perimeter of cf-organization and the ingress rules of its
  integrations, in the perimeter's dry-run or enforced mode.

The calling configuration iterates over its projects.

## Usage

```hcl
module "gcp_project" {
  source  = "damsoncloud/cf-gcp-project/google"
  version = "X.Y.Z"

  folders                      = module.hierarchy.folders
  environment                  = "production"
  name                         = "backend"
  billing_account              = "012345-6789AB-CDEF01"
  observability_project_id     = module.organization.observability_project_id
  billing_notification_channel = module.organization.billing_notification_channel

  services = ["run.googleapis.com"]
  labels   = { component = "backend", department = "engineering", owner = "team-backend" }
}
```

Pin an exact version. New versions are published as immutable GitHub releases with `vX.Y.Z` tags, following [semantic versioning](https://semver.org/).

<!-- BEGIN_TF_DOCS -->
<!-- markdownlint-capture -->
<!-- markdownlint-disable MD013 -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| billing\_account | ID of the billing account of the project and its budget, e.g. `012345-6789AB-CDEF01`. | `string` | n/a | yes |
| billing\_disabler | The billing disabler, disabling the project's billing when its budget is exceeded; not enabled when null:   `topic`, the topic of its budget notifications, e.g. the `billing_disabler_topic` output of cf-observability;   `email`, its service account, e.g. the `billing_disabler_email` output of cf-organization;   `project_roles`, the service account's roles on the project, e.g. the `billing_disabler_project_roles` output of cf-organization. | ```object({ topic = string email = string project_roles = list(string) })``` | `null` | no |
| billing\_notification\_channel | ID of the notification channel of the billing administrators, notified of the budget's alerts, e.g. the `billing_notification_channel` output of cf-organization. | `string` | n/a | yes |
| budget | The project's budget: `amount`, in the billing account's currency; `thresholds`, the fractions of the amount alerting the billing administrators. | ```object({ amount = optional(number, 100) thresholds = optional(list(number), [0.5, 0.7, 1.0]) })``` | `{}` | no |
| deletion\_policy | Whether Terraform can delete the project: `PREVENT`, `ABANDON` (removed from the state only) or `DELETE`. | `string` | `"PREVENT"` | no |
| display\_name | Display name of the project; its ID when null. | `string` | `null` | no |
| environment | Name of the environment folder of the project, a key of `folders` with a short name, e.g. `production`. The short name prefixes the generated project ID and is the project's `environment` label. | `string` | n/a | yes |
| essential\_contacts | Essential contacts of the project, in addition to those inherited from the organisation and its folder: the notification categories by email, e.g. `{ "team@example.com" = ["TECHNICAL", "SECURITY"] }`. | `map(list(string))` | `{}` | no |
| essential\_contacts\_language | Language of the essential contacts' notifications, as a BCP-47 tag. | `string` | `"en-GB"` | no |
| folders | The folders by folder name, e.g. the `folders` output of cf-hierarchy: `id`, the resource name (`folders/<id>`); `short_name`, the environment's short name, null for folders other than environments; `common`, whether it is the common environment. | ```map(object({ id = string short_name = optional(string) common = optional(bool, false) }))``` | n/a | yes |
| labels | Labels of the project, following the labelling strategy of the customer design document: at least `component`, `department` and `owner`, e.g. a team name or an email with `_at_` and `_` in place of `@` and dots. The `environment` label is set to the environment's short name. | `map(string)` | n/a | yes |
| name | Name of the project, generating its ID `<environment short name>-<name>-<suffix>` with a random 4 hexadecimal characters suffix, e.g. `prod-backend-a1b2`. | `string` | n/a | yes |
| observability\_project\_id | ID of the Observability project, e.g. the `observability_project_id` output of cf-organization, whose metrics scope the project is added to. | `string` | n/a | yes |
| project\_id | ID of the project, replacing the generated one, e.g. to follow another naming pattern or to keep the ID of an existing project. | `string` | `null` | no |
| services | APIs enabled in the project, e.g. `run.googleapis.com`. They are left enabled when removed from the list. | `list(string)` | `[]` | no |
| vpc\_service\_controls | The VPC Service Controls perimeter of the production and common environments, e.g. of cf-organization's vpc-service-controls submodule; not used when null:   `perimeter_name`, the perimeter's resource name, e.g. the submodule's `perimeter_name` output;   `mode`, the submodule's mode: the ingress rules are added to the dry-run configuration, and to the enforced one too when `enforced`;   `environments`, the folder names of the environments in the perimeter, to whose configurations the project is added when it is in one of them;   `ingress_rules`, the project's ingress rules, e.g. of its integrations, by title, added when the project is in the perimeter:     `identities` or `identity_type` (`ANY_IDENTITY`, `ANY_USER_ACCOUNT` or `ANY_SERVICE_ACCOUNT`), the principals allowed;     `source_access_levels`, the names of the access policy's access levels or `*` for any source, and `source_resources`, e.g. `projects/<number>`;     `operations`, the methods by service into the project, `*` for all services, and all methods of a service when its list is empty. | ```object({ perimeter_name = string mode = optional(string, "dry_run") environments = optional(list(string), ["production", "common"]) ingress_rules = optional(map(object({ identities = optional(list(string), []) identity_type = optional(string) source_access_levels = optional(list(string), ["*"]) source_resources = optional(list(string), []) operations = optional(map(list(string)), { "*" = [] }) })), {}) })``` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| budget | Resource name of the project's budget (`billingAccounts/<id>/budgets/<id>`). |
| perimeter\_member | Whether the project was added to the VPC Service Controls perimeter. |
| project\_id | ID of the project. |
| project\_number | Number of the project. |
<!-- markdownlint-restore -->
<!-- END_TF_DOCS -->

## Releases

Releases are dispatched manually on `main` with the [`release.yaml`](.github/workflows/release.yaml) workflow, choosing the part of the version to increase. It calls the
[`github-release.yaml`](https://github.com/damsoncloud/dcp.sdlc#reusable-workflows) reusable workflow, which creates the GitHub release and its tag. The Terraform Registry
publishes the new version from the tag.

## Security

See [SECURITY.md](SECURITY.md) for how to report vulnerabilities.

## Development

The repository uses [devenv](https://devenv.sh) with the shared [devenvbase](https://github.com/damsoncloud/dcp.sdlc/blob/main/devenvbase/README.md), pinned to a
[dcp.sdlc](https://github.com/damsoncloud/dcp.sdlc) release in `devenv.yaml`.

* `devenv shell` starts the shell.
* `devenv test` runs the git hooks and tests.
* `terraform_docs` regenerates the inputs and outputs above, which the `terraform-docs` git hook also does on commit.

The weekly `dcp.sdlc check` workflow opens an issue when a newer dcp.sdlc release is available. Upgrade with `devenv shell -- dcp_sdlc_upgrade_pr`, which also updates
the devenv inputs, runs the tests and opens a pull request.

## Licence

[Apache License 2.0](LICENSE)
