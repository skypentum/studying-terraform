### reference : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block
---

bucket - (Required) S3 Bucket to which this Public Access Block configuration should be applied.

block_public_acls - (Optional) Whether Amazon S3 should block public ACLs for this bucket. Defaults to false. Enabling this setting does not affect existing policies or ACLs. When set to true causes the following behavior:
  - PUT Bucket acl and PUT Object acl calls will fail if the specified ACL allows public access.
  - PUT Object calls will fail if the request includes an object ACL.

block_public_policy - (Optional) Whether Amazon S3 should block public bucket policies for this bucket. Defaults to false. Enabling this setting does not affect the existing bucket policy. When set to true causes Amazon S3 to:
  - Reject calls to PUT Bucket policy if the specified bucket policy allows public access.

ignore_public_acls - (Optional) Whether Amazon S3 should ignore public ACLs for this bucket. Defaults to false. Enabling this setting does not affect the persistence of any existing ACLs and doesn't prevent new public ACLs from being set. When set to true causes Amazon S3 to:
  - Ignore public ACLs on this bucket and any objects that it contains.

restrict_public_buckets - (Optional) Whether Amazon S3 should restrict public bucket policies for this bucket. Defaults to false. Enabling this setting does not affect the previously stored bucket policy, except that public and cross-account access within the public bucket policy, including non-public delegation to specific accounts, is blocked. When set to true:
  - Only the bucket owner and AWS Services can access this buckets if it has a public policy.
