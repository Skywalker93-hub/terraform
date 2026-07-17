// Providers
terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.215.0"
    }
  }

  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket = "terraform-state-urnwerwer"
    region = "ru-central1"
    key    = "test-terraform/main.tfstate"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true

  }
  required_version = "~> 1.12"

}

provider "yandex" {
  zone                     = "ru-central1-a"
  service_account_key_file = pathexpand("~/.config/yandex-cloud/terraform-sa-key.json")
}

// VPC Network
resource "yandex_vpc_network" "my_net" {
  name = "test-test-network"
}

// VPC Subnet-1
resource "yandex_vpc_subnet" "subnet1" {
  v4_cidr_blocks = ["10.10.1.0/24"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.my_net.id
}

// VPC Subnet-2
resource "yandex_vpc_subnet" "subnet2" {
  v4_cidr_blocks = ["10.10.2.0/24"]
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.my_net.id
}

// VPC Subnet-3
resource "yandex_vpc_subnet" "subnet3" {
  v4_cidr_blocks = ["10.10.3.0/24"]
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.my_net.id
}

// Rules in Security Group for three VMs
resource "yandex_vpc_default_security_group" "sg" {
  description = "default sg"
  network_id  = yandex_vpc_network.my_net.id

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  egress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }

}

// Get image ID for Ubuntu 26.04 LTS 
data "yandex_compute_image" "ubuntu_2604" {
  family = "ubuntu-2604-lts"
}

// Create disk-1
resource "yandex_compute_disk" "boot" {
  name = "ubuntu-2604-boot"
  zone = "ru-central1-a"
  type = "network-ssd"
  size = 30

  image_id = data.yandex_compute_image.ubuntu_2604.id
}

// Create disk-2
resource "yandex_compute_disk" "boot2" {
  name = "ubuntu-2604-boot2"
  zone = "ru-central1-b"
  type = "network-ssd"
  size = 30

  image_id = data.yandex_compute_image.ubuntu_2604.id
}

// Create disk-3
resource "yandex_compute_disk" "boot3" {
  name = "ubuntu-2604-boot3"
  zone = "ru-central1-d"
  type = "network-ssd"
  size = 30

  image_id = data.yandex_compute_image.ubuntu_2604.id
}

// New instance "web"
resource "yandex_compute_instance" "web" {
  name        = "web"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    disk_id     = yandex_compute_disk.boot.id
    auto_delete = false
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet1.id
    nat       = true

    security_group_ids = [
      yandex_vpc_default_security_group.sg.id
    ]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

// New instance "app"
resource "yandex_compute_instance" "app" {
  name        = "app"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    disk_id     = yandex_compute_disk.boot2.id
    auto_delete = false
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet2.id
    nat       = true

    security_group_ids = [
      yandex_vpc_default_security_group.sg.id
    ]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

// New instance "monitoring"
resource "yandex_compute_instance" "monitoring" {
  name        = "monitoring"
  platform_id = "standard-v3"
  zone        = "ru-central1-d"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    disk_id     = yandex_compute_disk.boot3.id
    auto_delete = false
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet3.id
    nat       = true

    security_group_ids = [
      yandex_vpc_default_security_group.sg.id
    ]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

// Save output data
output "web_external_ip" {
  value = yandex_compute_instance.web.network_interface[0].nat_ip_address
}

output "app_external_ip" {
  value = yandex_compute_instance.app.network_interface[0].nat_ip_address
}

output "monitoring_external_ip" {
  value = yandex_compute_instance.monitoring.network_interface[0].nat_ip_address
}

// Create inventory.ini 
resource "local_file" "inventory" {
  filename = "${path.module}/ansible/inventory.ini"

  content = <<EOF
[web]
${yandex_compute_instance.web.network_interface[0].nat_ip_address}

[app]
${yandex_compute_instance.app.network_interface[0].nat_ip_address}

[monitoring]
${yandex_compute_instance.monitoring.network_interface[0].nat_ip_address}
EOF
}