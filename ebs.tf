# =========================================================================
# Elastic Block Store (EBS) Configuration
# =========================================================================

# =========================================================================
# 1. Kafka Broker Storage
# =========================================================================

resource "aws_ebs_volume" "kafka_data" {
  count             = 3
  availability_zone = aws_instance.kafka_brokers[count.index].availability_zone
  size              = 100
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "Kafka-Data-Vol-${count.index + 1}"
    Type = "Kafka-Storage"
  }
}

resource "aws_volume_attachment" "kafka_attach" {
  count       = 3
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.kafka_data[count.index].id
  instance_id = aws_instance.kafka_brokers[count.index].id
}

# =========================================================================
# 2. App Node Storage (Docker Volumes)
# =========================================================================

resource "aws_ebs_volume" "app_data" {
  count             = 3
  availability_zone = aws_instance.app_nodes[count.index].availability_zone
  size              = 50
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "App-Node-Vol-${count.index + 1}"
    Type = "App-Storage"
  }
}

resource "aws_volume_attachment" "app_attach" {
  count       = 3
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.app_data[count.index].id
  instance_id = aws_instance.app_nodes[count.index].id
}

# =========================================================================
# 3. Zookeeper Storage
# =========================================================================

resource "aws_ebs_volume" "zookeeper_data" {
  count             = 3
  availability_zone = aws_instance.zookeeper_nodes[count.index].availability_zone
  size              = 20
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "Zookeeper-Data-Vol-${count.index + 1}"
    Type = "Zookeeper-Storage"
  }
}

resource "aws_volume_attachment" "zookeeper_attach" {
  count       = 3
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.zookeeper_data[count.index].id
  instance_id = aws_instance.zookeeper_nodes[count.index].id
}

# =========================================================================
# 4. Automated Backups (Data Lifecycle Manager)
# =========================================================================
/*
# Retrieve the existing LabRole provided by AWS Academy
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

resource "aws_dlm_lifecycle_policy" "daily_snapshots" {
  description        = "Daily snapshots for persistent storage"
  execution_role_arn = data.aws_iam_role.lab_role.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    target_tags = {
      Type = "Kafka-Storage"
    }
    # Note: You can add more target tags or create separate policies if needed.
    # Currently targeting Kafka as a critical example. 

    schedule {
      name = "Daily Backups"
      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["03:00"]
      }

      retain_rule {
        count = 7
      }

      tags_to_add = {
        SnapshotCreator = "DLM"
      }

      copy_tags = true
    }
  }
}
*/
