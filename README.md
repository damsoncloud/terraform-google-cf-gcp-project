# Damson Cloud GCP Cloud Foundations: GCP project

Terraform module of the Damson Cloud GCP Cloud Foundations creating a single workload project:

* the project in its environment's folder, with a generated `<environment short name>-<name>-<suffix>` ID, its APIs, labels and essential contacts,
* the project's membership of the Observability project's metrics scope.

The calling configuration iterates over its projects.

## Usage

```hcl
module "gcp_project" {
  source  = "damsoncloud/cf-gcp-project/google"
  version = "X.Y.Z"

  folders                  = module.hierarchy.folders
  environment              = "production"
  name                     = "backend"
  billing_account          = "012345-6789AB-CDEF01"
  observability_project_id = module.organization.observability_project_id

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

## Outputs

| Name | Description |
| ---- | ----------- |
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
