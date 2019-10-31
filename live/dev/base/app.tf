module "terrainfra_dev_svcs_app" {
  source = "../../../modules/services/webserver-cluster"

  config = local.config
  data = module.terrainfra_dev_network.data

  mod = {
    name = "${local.config.name}-services-app-web-cluster"

    user_data = templatefile(
      "${path.module}/templates/app.tmpl.sh", {
        http_port = local.config.elb_port.instance
      }
    )

    image_id      = local.config.image_id
    instance_type = local.config.instance_type
    min_size      = 2
    max_size      = 4
  }
}
