locals {
  shared_vpc_network = try(var.shared_vpc.networks[var.environment], null)

  shared_vpc_subnets = local.shared_vpc_network == null ? {} : {
    for region, subnet in local.shared_vpc_network.subnets : region => subnet if var.shared_vpc.regions == null || contains(coalesce(var.shared_vpc.regions, []), region)
  }

  # The Google APIs service agent, e.g. creating managed instance groups' instances, the given services' agents and further principals,
  # keyed by values known before the project is created
  shared_vpc_subnet_users = local.shared_vpc_network == null ? {} : merge(
    { cloudservices = "serviceAccount:${google_project.project.number}@cloudservices.gserviceaccount.com" },
    { for name in var.shared_vpc.service_agents : name => "serviceAccount:service-${google_project.project.number}@${name}.iam.gserviceaccount.com" },
    { for member in var.shared_vpc.subnet_users : member => member },
  )

  shared_vpc_subnet_bindings = merge([
    for region in keys(local.shared_vpc_subnets) : {
      for key, member in local.shared_vpc_subnet_users : "${region}/${key}" => { region = region, member = member }
    }
  ]...)
}

resource "google_compute_shared_vpc_service_project" "project" {
  count = local.shared_vpc_network == null ? 0 : 1

  host_project    = local.shared_vpc_network.project_id
  service_project = google_project_service.services["compute.googleapis.com"].project
}

# Granted on the subnets only, as a host project can hold the networks of several environments
resource "google_compute_subnetwork_iam_member" "shared_vpc" {
  for_each = local.shared_vpc_subnet_bindings

  project    = local.shared_vpc_network.project_id
  region     = each.value.region
  subnetwork = local.shared_vpc_subnets[each.value.region].name
  role       = "roles/compute.networkUser"
  member     = each.value.member

  # The service agents exist once their services are enabled
  depends_on = [google_project_service.services, google_compute_shared_vpc_service_project.project]
}
