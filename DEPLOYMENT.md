# AWS Free-Tier Deployment

Deploy the 5-service Deeks backend on one EC2 `t2.micro` using Docker Compose
and MongoDB Atlas M0 (both free tier).

## Cost guard

| Resource                       | Tier                          | Monthly cost |
|--------------------------------|-------------------------------|--------------|
| EC2 `t2.micro` (1 GB RAM)      | 750 hrs free for 12 months    | $0           |
| 30 GB EBS gp3 storage          | 30 GB free                    | $0           |
| Elastic IP (attached)          | free while attached           | $0           |
| MongoDB Atlas M0 (512 MB)      | forever-free shared cluster   | $0           |
| Data transfer out              | 100 GB free/month             | $0           |

**Stay on free tier by:** running exactly one EC2 instance, keeping its IP
attached (detached Elastic IPs cost $0.005/hr), using a single Atlas M0 cluster,
and not enabling CloudWatch detailed monitoring.

## Prerequisites

- AWS account (with free-tier eligibility).
- MongoDB Atlas account (free).
- SSH keypair for EC2 access.
- Domain name (optional — can use EC2 public IP for dev).

## 1. Create MongoDB Atlas cluster

1. Sign up at https://www.mongodb.com/cloud/atlas.
2. **Build a Cluster → M0 (free tier)**. Pick AWS as provider and the region
   closest to where you'll run EC2.
3. Under **Database Access**, create a user (`deeks_app`) with a strong password.
4. Under **Network Access**, temporarily allow `0.0.0.0/0` (we'll restrict to the
   EC2 IP after step 2).
5. Under **Database → Connect → Drivers**, copy the connection string. It looks like:
   ```
   mongodb+srv://deeks_app:<password>@cluster0.xxx.mongodb.net/?retryWrites=true&w=majority
   ```
6. Build 5 per-service URIs by appending the DB name before the `?`:
   - `mongodb+srv://.../auth_db?retryWrites=true&w=majority`
   - `.../meetings_db?...`
   - `.../links_db?...`
   - `.../passwords_db?...`
   - `.../notes_db?...`

## 2. Launch EC2 `t2.micro`

1. EC2 Console → **Launch instance**.
2. AMI: **Amazon Linux 2023** (or Ubuntu 22.04 LTS).
3. Instance type: **`t2.micro`** (free tier).
4. Key pair: select or create one, download `.pem`.
5. Network: allow inbound **SSH (22) from your IP** and **HTTP (80) from anywhere**.
6. Storage: 20 GB gp3 (within free tier).
7. Launch and wait ~1 min.
8. Allocate an **Elastic IP** and associate it with the instance (so the IP
   survives reboots).

## 3. Install Docker on the instance

SSH in:
```bash
ssh -i ~/deeks.pem ec2-user@<your-elastic-ip>
```

Install Docker + Compose:
```bash
sudo dnf update -y
sudo dnf install -y docker git
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
# log out and back in so the group takes effect
mkdir -p ~/.docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose
docker compose version
```

## 4. Ship the code

From your laptop:
```bash
# The simplest path — clone via SCP since we have no remote:
rsync -avz --exclude node_modules --exclude build --exclude dist \
  backend/ ec2-user@<ip>:/home/ec2-user/deeks-backend/
```

Or push to a private GitHub repo and `git clone` on the instance.

## 5. Configure environment

On the instance:
```bash
cd ~/deeks-backend
cp .env.example .env
nano .env
```

Fill in:
```env
JWT_SECRET=<output of: openssl rand -hex 32>
MONGO_URI_AUTH=mongodb+srv://.../auth_db?retryWrites=true&w=majority
MONGO_URI_MEETINGS=mongodb+srv://.../meetings_db?retryWrites=true&w=majority
MONGO_URI_LINKS=mongodb+srv://.../links_db?retryWrites=true&w=majority
MONGO_URI_PASSWORDS=mongodb+srv://.../passwords_db?retryWrites=true&w=majority
MONGO_URI_NOTES=mongodb+srv://.../notes_db?retryWrites=true&w=majority
```

## 6. Start the stack

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

First build takes ~5-8 min (five NestJS images). Subsequent restarts are fast.

Verify:
```bash
curl http://localhost/health          # -> ok
curl -X POST http://localhost/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"me@example.com","password":"supersecret"}'
```

## 7. Lock down MongoDB Atlas

In Atlas → Network Access, **remove `0.0.0.0/0`** and add only the EC2 Elastic IP.

## 8. Point the mobile app at the server

In `mobile/lib/api/api_client.dart`, change:
```dart
const String kApiBaseUrl = 'http://10.0.2.2/api';
```
to
```dart
const String kApiBaseUrl = 'http://<your-elastic-ip>/api';
```
Rebuild the APK: `flutter build apk --release`.

## 9. Memory pressure — the honest caveat

On `t2.micro` (1 GB RAM) you have 5 Node services (~100 MB each at idle)
+ nginx + OS = tight. The `--max-old-space-size=128` flag on each service
keeps each Node heap bounded. Expect:
- Idle: ~700 MB used, ~300 MB free.
- Under load (several concurrent requests): brief spikes to >900 MB, possible
  OOM on the weakest service.

**If you hit OOM:**
1. Upgrade to `t3.small` (2 GB RAM, ~$15/month — outside free tier).
2. Or consolidate: merge `links-service` + `notes-service` into one container.
3. Or add 1 GB of swap (trades RAM pressure for slower responses):
   ```bash
   sudo dd if=/dev/zero of=/swapfile bs=1M count=1024
   sudo mkswap /swapfile && sudo chmod 600 /swapfile && sudo swapon /swapfile
   echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
   ```

## 10. HTTPS (recommended before production use)

For a real domain, use Let's Encrypt via nginx. On the EC2 instance:
```bash
sudo dnf install -y certbot
# stop nginx container, get cert:
docker compose stop gateway
sudo certbot certonly --standalone -d api.yourdomain.com
# add the cert path to a volume mount in docker-compose.yml and
# update nginx.conf with a 443 server block.
```

Until then, the mobile client talks plain HTTP. That's fine for testing but
unsafe for real credentials — **do not rely on HTTP in a live vault deployment**.
JWT tokens and (unencrypted-by-this-layer) login passwords cross the wire in
the clear on HTTP. Note that password-vault *contents* remain safe regardless,
since they're E2E-encrypted on the device before transmission.
