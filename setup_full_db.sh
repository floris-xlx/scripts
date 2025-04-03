#!/bin/bash

# Default PostgreSQL password
DEFAULT_PG_PASSWORD="new_secure_password"
API_XYLEX_CLOUD="https://api.xylex.cloud"
POSTGRES_PORT=5432
POSTGRES_USERNAME=postgres
DB_XYLEX_CLOUD="https://db.xylex.cloud"
DB_XYLEX_CLOUD_HTTP="http://db.xylex.cloud"
DB_XYLEX_CLOUD_HOST="db.xylex.cloud"
START_PORT=4500

# Parse CLI arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
    --db_name)
        DB_NAME="$2"
        shift
        ;;
    --admin_email)
        ADMIN_EMAIL="$2"
        shift
        ;;
    --project_id)
        PROJECT_ID="$2"
        shift
        ;;
    *)
        echo "Unknown parameter passed: $1"
        exit 1
        ;;
    esac
    shift
done

# Check if required arguments are provided
if [ -z "$DB_NAME" ] || [ -z "$ADMIN_EMAIL" ] || [ -z "$PROJECT_ID" ]; then
    echo "Usage: $0 --db_name <database_name> --admin_email <admin_email> --project_id <project_id>"
    exit 1
fi

ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 16)
echo -e "\e[1;33m[✔] Generated ADMIN_PASSWORD: $ADMIN_PASSWORD\e[0m"

# Clean the DB_NAME by replacing non-alphanumeric characters with '_'
CLEAN_DB_NAME=$(echo "$DB_NAME" | sed 's/[^a-zA-Z0-9]/_/g')

# Call the /postgres/admin/databases get route and look at the name key in the array and look if the name already exists, on a name conflict
# just add -1 or -2 at the end
echo -e "\e[1;34mChecking if $CLEAN_DB_NAME is not conflicting with existing database names\e[0m"
EXISTS=$(curl -s "$API_XYLEX_CLOUD/postgres/admin/databases/exists/$CLEAN_DB_NAME" | jq -r '.exists')
if [ "$EXISTS" == "true" ]; then
    SUFFIX=1
    while [ "$(curl -s "$API_XYLEX_CLOUD/postgres/admin/databases/exists/${CLEAN_DB_NAME}_$SUFFIX" | jq -r '.exists')" == "true" ]; do
        SUFFIX=$((SUFFIX + 1))
    done
    CLEAN_DB_NAME="${CLEAN_DB_NAME}_$SUFFIX"
fi
echo -e "\e[1;32m[✔] Final Database Name: $CLEAN_DB_NAME\e[0m"

PG_PASSWORD=${PG_PASSWORD:-$DEFAULT_PG_PASSWORD}
export PGPASSWORD=$PG_PASSWORD
echo -e "\e[1;32m[✔] PostgreSQL password set.\e[0m"

# Check for available port on the networking API
PORT=$START_PORT
while true; do
    RESPONSE=$(curl -s "$API_XYLEX_CLOUD/networking/check_port?port=$PORT&protocol=all")
    FREE=$(echo $RESPONSE | jq -r '.data.free')
    if [ "$FREE" == "true" ]; then
        break
    fi
    PORT=$((PORT + 1))
done
echo -e "\e[1;34m[✔] Using Port $PORT for PostgREST\e[0m"

# Generate a secure JWT secret key
SECRET_KEY=$(openssl rand -hex 32)
echo -e "\e[1;33m[✔] Generated SECRET_KEY: $SECRET_KEY\e[0m"

# Create PostgreSQL database
echo -e "\e[1;32m[✔] Creating PostgreSQL database: $CLEAN_DB_NAME\e[0m"
psql -U $POSTGRES_USERNAME -h $DB_XYLEX_CLOUD_HOST -p $POSTGRES_PORT -c "CREATE DATABASE $CLEAN_DB_NAME;"

# Create users table in the new database
echo -e "\e[1;34m[✔] Creating users table in $CLEAN_DB_NAME\e[0m"
psql -U $POSTGRES_USERNAME -h $DB_XYLEX_CLOUD_HOST -p $POSTGRES_PORT -d $CLEAN_DB_NAME -c "
CREATE TABLE IF NOT EXISTS public.users (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL
);
INSERT INTO public.users (name, email, password) 
VALUES ('Admin', '$ADMIN_EMAIL', '$ADMIN_PASSWORD') 
ON CONFLICT (email) DO NOTHING;
" || {
    echo -e "\e[1;31m Error creating user record in $CLEAN_DB_NAME \e[0m"
    exit 1
}

# Create role for authenticated role for JWT users
echo -e "\e[1;34m[✔] Creating authenticated role for JWT users in $CLEAN_DB_NAME\e[0m"
psql -U $POSTGRES_USERNAME -h $DB_XYLEX_CLOUD_HOST -p $POSTGRES_PORT -d $CLEAN_DB_NAME -c "CREATE ROLE authenticated NOLOGIN;" | grep -q "CREATE ROLE" && {
    echo -e "\e[1;32m[✔] Role 'authenticated' created successfully.\e[0m"
} || {
    if psql -U $POSTGRES_USERNAME -h $DB_XYLEX_CLOUD_HOST -p $POSTGRES_PORT -d $CLEAN_DB_NAME -c "\du" | grep -qw "authenticated"; then
        # Role 'authenticated' already exists, skip creation
        :
    else
        echo -e "\e[1;31m[✘] Failed to create role 'authenticated'.\e[0m"
        exit 1
    fi
}

# Grant authenticated users full access
psql -U $POSTGRES_USERNAME -h $DB_XYLEX_CLOUD_HOST -p $POSTGRES_PORT -d $CLEAN_DB_NAME -c "
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.users TO authenticated;
" | grep -q "GRANT" && {
    echo -e "\e[1;32m[✔] Granted full access to 'authenticated' role.\e[0m"
} || {
    echo -e "\e[1;31m[✘] Failed to grant privileges to 'authenticated' role.\e[0m"
    exit 1
}

# Check if pgjwt is installed and install it if missing
echo -e "\e[1;34m[✔] Checking for pgjwt extension in $CLEAN_DB_NAME\e[0m"
PGJWT_EXISTS=$(psql -U $POSTGRES_USERNAME -h $DB_XYLEX_CLOUD_HOST -p $POSTGRES_PORT -d $CLEAN_DB_NAME -tAc "SELECT count(*) FROM pg_extension WHERE extname='pgjwt';")
if [ "$PGJWT_EXISTS" -eq "0" ]; then
    echo -e "\e[1;33m[✘] pgjwt extension not found. Installing pgjwt...\e[0m"

    # Ensure pgcrypto is installed before pgjwt
    psql -U $POSTGRES_USERNAME -h $DB_XYLEX_CLOUD_HOST -p $POSTGRES_PORT -d $CLEAN_DB_NAME -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;" || {
        echo -e "\e[1;31m Error creating extension pgcrypto in $CLEAN_DB_NAME \e[0m"
        exit 1
    }
    psql -U $POSTGRES_USERNAME -h $DB_XYLEX_CLOUD_HOST -p $POSTGRES_PORT -d $CLEAN_DB_NAME -c "CREATE EXTENSION IF NOT EXISTS pgjwt;" || {
        echo -e "\e[1;31m Error creating extension pgjwt in $CLEAN_DB_NAME \e[0m"
        exit 1
    }

    echo -e "\e[1;32m[✔] pgjwt extension installed.\e[0m"
fi

echo -e "\e[1;34m[✔] Verifying pgjwt installation by checking 'sign' function\e[0m"
SIGN_FUNCTION_CHECK=$(psql -U $POSTGRES_USERNAME -h $DB_XYLEX_CLOUD_HOST -p $POSTGRES_PORT -d $CLEAN_DB_NAME -c "\df sign" | grep -c "sign")

if [ "$SIGN_FUNCTION_CHECK" -gt 0 ]; then
    echo -e "\e[1;32m[✔] 'sign' function is available in the database.\e[0m"
else
    echo -e "\e[1;31m[✘] 'sign' function is not available. Please check the pgjwt installation.\e[0m"
fi

echo -e "\e[1;34m[✔] Ensuring password column exists in users table\e[0m"
PASSWORD_COLUMN_CHECK=$(psql -U $POSTGRES_USERNAME -h $DB_XYLEX_CLOUD_HOST -p $POSTGRES_PORT -d $CLEAN_DB_NAME -c "\d public.users" | grep -c "password")

if [ "$PASSWORD_COLUMN_CHECK" -eq 0 ]; then
    echo -e "\e[1;33m[✘] Password column not found. Adding password column to users table...\e[0m"
    psql -U $POSTGRES_USERNAME -h $DB_XYLEX_CLOUD_HOST -p $POSTGRES_PORT -d $CLEAN_DB_NAME -c "
    ALTER TABLE public.users ADD COLUMN IF NOT EXISTS password TEXT NOT NULL DEFAULT 'default_password';
    "
    echo -e "\e[1;32m[✔] Password column added to users table.\e[0m"
else
    echo -e "\e[1;34m[✔] Password column already exists in users table.\e[0m"
fi

# Create auth_token function
echo "[✔] Creating auth_token function in $CLEAN_DB_NAME"
psql -U $POSTGRES_USERNAME -h $DB_XYLEX_CLOUD_HOST -p $POSTGRES_PORT -d $CLEAN_DB_NAME -c "
CREATE FUNCTION public.auth_token(email TEXT, password TEXT) RETURNS TEXT AS \$\$
DECLARE
    user_id INT;
    role TEXT;
    token TEXT;
BEGIN
    -- Validate User
    SELECT id, 'authenticated' INTO user_id, role
    FROM public.users
    WHERE users.email = auth_token.email
    AND users.password = auth_token.password;

    IF user_id IS NULL THEN
        RETURN NULL; -- Invalid credentials
    END IF;

    -- Ensure $(exp) is an integer
    SELECT sign(
        json_build_object(
            'role', role,
            'email', email,
            'exp', CAST(extract(epoch FROM now() + interval '24 years') AS bigint)
        )::json, '$SECRET_KEY'::text, 'HS256'::text) INTO token;

    RETURN token;
END;
\$\$ LANGUAGE plpgsql;
"

# Create PostgREST config file
POSTGREST_CONF="/etc/postgrest_$CLEAN_DB_NAME.conf"
echo "[✔] Creating PostgREST config file: $POSTGREST_CONF"
echo "floris" | sudo -S bash -c "cat > $POSTGREST_CONF" <<EOL
db-uri = "postgres://postgres:$PG_PASSWORD@$DB_XYLEX_CLOUD_HOST/$CLEAN_DB_NAME"
db-schema = "public"
db-anon-role = "web_anon"
db-channel = "pgrst"
db-channel-enabled = false
jwt-secret = "$SECRET_KEY"
role-claim-key = ".role"
server-port = $PORT
EOL

# Create systemd service for PostgREST
SERVICE_FILE="/etc/systemd/system/postgrest_$CLEAN_DB_NAME.service"
echo -e "\e[1;34m[✔] Creating systemd service file: $SERVICE_FILE\e[0m"
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=PostgREST API for $CLEAN_DB_NAME
After=network.target

[Service]
ExecStart=/usr/local/bin/postgrest $POSTGREST_CONF
Restart=always
User=postgres
Group=postgres
Environment=PGDATABASE=$CLEAN_DB_NAME

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd and start PostgREST
echo -e "\e[32m[✔] Reloading systemd and starting postgrest_$CLEAN_DB_NAME\e[0m"
# Reload systemd daemon
if sudo systemctl daemon-reload; then
    echo -e "\e[32m[✔] Successfully reloaded systemd daemon.\e[0m"
else
    echo -e "\e[31m[✖] Failed to reload systemd daemon.\e[0m"
    exit 1
fi

# Enable PostgREST service
if sudo systemctl enable postgrest_$CLEAN_DB_NAME; then
    echo -e "\e[32m[✔] Successfully enabled postgrest_$CLEAN_DB_NAME service.\e[0m"
else
    echo -e "\e[31m[✖] Failed to enable postgrest_$CLEAN_DB_NAME service.\e[0m"
    exit 1
fi

# Start PostgREST service
if sudo systemctl start postgrest_$CLEAN_DB_NAME; then
    echo -e "\e[32m[✔] Successfully started postgrest_$CLEAN_DB_NAME service.\e[0m"
else
    echo -e "\e[31m[✖] Failed to start postgrest_$CLEAN_DB_NAME service.\e[0m"
    exit 1
fi

# Update Nginx configuration
NGINX_CONF="/etc/nginx/sites-available/$DB_XYLEX_CLOUD_HOST"
# Ensure the file exists
if [ ! -f "$NGINX_CONF" ]; then
    echo -e "\e[38;5;208m[!] Nginx config does not exist! Creating new config.\e[0m"
    sudo bash -c "cat > $NGINX_CONF" <<EOL
server {
    listen 80;
    server_name $DB_XYLEX_CLOUD_HOST

    location ~ ^/(?<db_id>[^/]+)/(.*)$ {
        set \$upstream "";
        
        if (\$db_id = "$CLEAN_DB_NAME") {
            set \$upstream "http://127.0.0.1:$PORT";
        }

        rewrite ^/[^/]+/(.*)$ /$1 break;
        proxy_pass \$upstream;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOL
else
    # Append to existing location block without duplication
    if ! grep -q "if (\$db_id = \"$CLEAN_DB_NAME\")" "$NGINX_CONF"; then
        echo -e "\e[32m[✔] Appending database $CLEAN_DB_NAME (port $PORT) to Nginx config.\e[0m"
        sudo sed -i "/set \$upstream \"\";/a \\
        if (\$db_id = \"$CLEAN_DB_NAME\") { \\
            set \$upstream \"http://127.0.0.1:$PORT\"; \\
        }" "$NGINX_CONF"
    else
        echo -e "\e[31m[✔] Database $CLEAN_DB_NAME already exists in Nginx config.\e[0m"
    fi
fi

# Restart Nginx
echo -e "\e[34m[✔] Restarting Nginx\e[0m"
sudo ln -sf /etc/nginx/sites-available/$DB_XYLEX_CLOUD_HOST /etc/nginx/sites-enabled/
if sudo systemctl restart nginx; then
    echo -e "\e[32m[✔] Successfully restarted Nginx.\e[0m"
else
    echo -e "\e[31m[✖] Failed to restart Nginx. Please check the service status.\e[0m"
    exit 1
fi

# Generate JWT Token
echo -e "\e[34m[✔] Generating JWT Token for admin user...\e[0m"
JWT=$(psql -U $POSTGRES_USERNAME -h $DB_XYLEX_CLOUD_HOST -p $POSTGRES_PORT -d $CLEAN_DB_NAME -t -c "SELECT auth_token('$ADMIN_EMAIL', '$ADMIN_PASSWORD');" | tr -d '[:space:]')
echo -e "\e[32m[✔] Generated JWT Token: $JWT\e[0m"

# Check if the service is online using the API
echo -e "\e[34m[✔] Checking if the database router service is online for $CLEAN_DB_NAME...\e[0m"
RESPONSE=$(curl -s "https://api.xylex.cloud/service/status?name=postgrest_$CLEAN_DB_NAME")
ONLINE_STATUS=$(echo "$RESPONSE" | jq -r '.data.online')

if [ "$ONLINE_STATUS" == "true" ]; then
    echo -e "\e[32m[✔] Service is online and reachable.\e[0m"
else
    echo -e "\e[31m[!] Service is not online. Please check the service status.\e[0m"
    sudo systemctl status postgrest_$CLEAN_DB_NAME.service
fi

# Generate UUID v4 and store it in the variable DB_UUID
DB_UUID=$(cat /proc/sys/kernel/random/uuid)
echo -e "\e[32m[✔] Generated UUID v4: $DB_UUID\e[0m"
MONITOR_UUID=$(cat /proc/sys/kernel/random/uuid)
echo -e "\e[32m[✔] Generated (monitor_uuid): $DB_UUID\e[0m"



# Prepare JSON body for API call
JSON_BODY=$(jq -n \
    --arg slug "$CLEAN_DB_NAME" \
    --arg project_id "$PROJECT_ID" \
    --arg name "$CLEAN_DB_NAME" \
    --arg password "$PG_PASSWORD" \
    --arg username "postgres" \
    --arg anon_key "$JWT" \
    --arg connection_string "postgres://postgres:$PG_PASSWORD@$DB_XYLEX_CLOUD_HOST/$CLEAN_DB_NAME" \
    --arg jwt_secret "$SECRET_KEY" \
    --arg jwt_key "$JWT" \
    --arg db_password "$ADMIN_PASSWORD" \
    --argjson postgrest_port $PORT \
    --arg host "$DB_XYLEX_CLOUD_HOST" \
    --arg admin_email "$ADMIN_EMAIL" \
    --arg db_id "$DB_UUID" \
    --arg pg_owner "postgres" \
    --arg postgrest_systemd_service_file "/etc/systemd/system/postgrest_$CLEAN_DB_NAME.service" \
    --arg postgrest_systemd_service_name "postgrest_$CLEAN_DB_NAME" \
    --arg postgrest_systemd_service_status "active" \
    --arg rest_endpoint "$DB_XYLEX_CLOUD_HTTP/$CLEAN_DB_NAME/" \
    --argjson api_max_rows 1000 \
    --arg monitor_id "$MONITOR_UUID" \
    --arg monitor_type "systemd_service" \
    --arg postgrest_config_file "/etc/postgrest_$CLEAN_DB_NAME.conf" \
    '{
        slug: $slug,
        project_id: $project_id,
        name: $name,
        password: $password,
        username: $username,
        anon_key: $anon_key,
        connection_string: $connection_string,
        jwt_secret: $jwt_secret,
        jwt_key: $jwt_key,
        db_password: $db_password,
        postgrest_port: $postgrest_port,
        host: $host,
        admin_email: $admin_email,
        db_id: $db_id,
        pg_owner: $pg_owner,
        postgrest_systemd_service_file: $postgrest_systemd_service_file,
        postgrest_systemd_service_name: $postgrest_systemd_service_name,
        postgrest_systemd_service_status: $postgrest_systemd_service_status,
        rest_endpoint: $rest_endpoint,
        api_max_rows: $api_max_rows,
        monitor_id: $monitor_id,
        monitor_type: $monitor_type,
        postgrest_config_file: $postgrest_config_file,
        
    }')

echo -e "\033[35m[✔] ✅ Done! Your new database '$CLEAN_DB_NAME' is ready at:\033[0m"

# Check the HTTP response code from the curl command
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}\n" -X POST "$API_XYLEX_CLOUD/postgres/create" \
    -H "Content-Type: application/json" \
    -d "$JSON_BODY")

# Echo the final status code
echo -e "\033[34m[✔] Final HTTP Status Code: $HTTP_STATUS\033[0m"

# Return 200 if the status code indicates success (2xx), otherwise return 500
if [[ "$HTTP_STATUS" =~ ^2 ]]; then
    exit 200
else
    exit 500
fi
