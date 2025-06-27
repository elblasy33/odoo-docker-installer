#!/bin/bash

# شعار Elblasy.app بشكل فني
echo -e "\033[1;36m"
cat << "EOF"
  ______ _           _                     
 |  ____| |         | |                    
 | |__  | | ___  ___| | __  __ _ _ __ ___  
 |  __| | |/ _ \/ __| |/ / / _` | '_ ` _ \ 
 | |____| |  __/\__ \   < | (_| | | | | | |
 |______|_|\___||___/_|\_(_)__,_|_| |_| |_|
         .app
EOF
echo -e "\033[0m"
echo -e "\033[1;33mتم التطوير بواسطة Elblasy.app - نسخة احترافية لإدارة أودو\033[0m"
echo -e "\033[1;33m=======================================================\033[0m\n"

# ألوان للواجهة
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# متغيرات التهيئة
ODOO_VERSIONS=("16" "17" "18")
SERVICES=("docker" "odoo" "nginx-proxy-manager" "webmin" "portainer")
BASE_PORT_ODOO=8069
BASE_PORT_WEBSERVICES=8080

# دالة للتحقق من الصلاحيات
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}يجب تشغيل السكربت كـ root!${NC}"
        exit 1
    fi
}

# دالة لتحديد التوزيعة
detect_distro() {
    echo -e "${YELLOW}ما هي توزيعة لينكس التي تستخدمها؟${NC}"
    select distro in "Ubuntu" "Debian" "CentOS/RHEL" "Fedora" "خروج"; do
        case $distro in
            "Ubuntu"|"Debian")
                DISTRO="ubuntu_debian"
                break
                ;;
            "CentOS/RHEL"|"Fedora")
                DISTRO="centos_fedora"
                break
                ;;
            "خروج")
                exit 0
                ;;
            *)
                echo -e "${RED}اختيار غير صحيح!${NC}"
                ;;
        esac
    done
}

# دالة لتنصيب الحزم
install_packages() {
    case $DISTRO in
        "ubuntu_debian")
            apt update
            apt install -y curl git docker.io docker-compose
            systemctl enable --now docker
            ;;
        "centos_fedora")
            yum install -y curl git docker docker-compose
            systemctl enable --now docker
            ;;
    esac
}

# دالة لعرض القائمة الرئيسية
show_menu() {
    clear
    echo -e "\033[1;36m"
    cat << "EOF"
  ______ _           _                     
 |  ____| |         | |                    
 | |__  | | ___  ___| | __  __ _ _ __ ___  
 |  __| | |/ _ \/ __| |/ / / _` | '_ ` _ \ 
 | |____| |  __/\__ \   < | (_| | | | | | |
 |______|_|\___||___/_|\_(_)__,_|_| |_| |_|
         .app
EOF
    echo -e "\033[0m"
    echo -e "${GREEN}===================================${NC}"
    echo -e "${GREEN}  مثبت Docker وأودو التلقائي       ${NC}"
    echo -e "${GREEN}===================================${NC}"
    echo -e "${YELLOW}الخدمات المتاحة:${NC}"
    
    declare -A service_desc
    service_desc["docker"]="Docker Engine"
    service_desc["odoo"]="Odoo (الإصدارات: ${ODOO_VERSIONS[*]})"
    service_desc["nginx-proxy-manager"]="Nginx Proxy Manager"
    service_desc["webmin"]="Webmin Control Panel"
    service_desc["portainer"]="Portainer Container Manager"

    for i in "${!SERVICES[@]}"; do
        echo -e "${GREEN}$((i+1)). ${service_desc[${SERVICES[$i]}]}${NC}"
    done

    echo -e "\n${YELLOW}الرجاء اختيار الخدمات (مثال: 1 2 3):${NC}"
    echo -e "${YELLOW}أو اكتب 'all' لتنصيب كل شيء:${NC}"
}

# دالة لتنصيب أودو
install_odoo() {
    local instance_num=$1
    local version=$2
    local port=$((BASE_PORT_ODOO + (instance_num * 10) + ${version} - 16))
    
    echo -e "${GREEN}جاري تنصيب Odoo ${version} (المثيل #${instance_num}) على المنفذ ${port}${NC}"

    # إنشاء مجلدات التهيئة
    mkdir -p /opt/odoo-${version}-${instance_num}/{addons,config,data,pgdata}
    
    # 1. إنشاء ملف odoo.conf مع ماستر باسورد
    cat > /opt/odoo-${version}-${instance_num}/config/odoo.conf <<EOF
[options]
admin_passwd = elblasy.app@123
db_host = postgres${version}-${instance_num}
db_port = 5432
db_user = odoo
db_password = odoo
addons_path = /mnt/extra-addons,/mnt/extra-addons
EOF

    # 2. إنشاء ملف requirements.txt
    cat > /opt/odoo-${version}-${instance_num}/requirements.txt <<EOF
# -----------------------
# | Add Python packages |
# -----------------------
# To install below packages at startup, uncomment this line in "docker-compose.yml" file!
# - ./entrypoint.sh:/entrypoint.sh
# then down the docker container (\$ docker-compose down) and up it again (\$ docker-compose up -d).
# -----------------------
paramiko==2.7.2 # for auto_backup module
EOF

    # 3. إنشاء entrypoint.sh
    cat > /opt/odoo-${version}-${instance_num}/entrypoint.sh <<EOF
#!/bin/bash

# تثبيت الحزم الإضافية
if [ -f /mnt/extra-addons/requirements.txt ]; then
    pip3 install -r /mnt/extra-addons/requirements.txt
fi

# تنفيذ نقطة الدخول الافتراضية
exec /entrypoint.sh "\$@"
EOF

    chmod +x /opt/odoo-${version}-${instance_num}/entrypoint.sh

    # 4. إنشاء docker-compose.yml
    cat > /opt/odoo-${version}-${instance_num}/docker-compose.yml <<EOF
version: '3'
services:
  odoo${version}-${instance_num}:
    image: odoo:${version}
    ports:
      - "${port}:8069"
    volumes:
      - ./addons:/mnt/extra-addons
      - ./config:/etc/odoo
      - ./data:/var/lib/odoo
      - ./entrypoint.sh:/entrypoint.sh
    command: ["--config=/etc/odoo/odoo.conf", "--log-level=info"]
    depends_on:
      - postgres${version}-${instance_num}

  postgres${version}-${instance_num}:
    image: postgres:13
    environment:
      POSTGRES_DB: postgres
      POSTGRES_USER: odoo
      POSTGRES_PASSWORD: odoo
    volumes:
      - ./pgdata:/var/lib/postgresql/data
EOF

    (cd /opt/odoo-${version}-${instance_num} && docker-compose up -d)
}

# دالة لتنصيب الخدمات الأخرى
install_service() {
    local service=$1
    
    case $service in
        "nginx-proxy-manager")
            echo -e "${GREEN}جاري تنصيب Nginx Proxy Manager على المنافذ 80,81,443${NC}"
            mkdir -p /opt/nginx-proxy-manager
            docker run -d \
                --name=nginx-proxy-manager \
                -p 80:80 \
                -p 81:81 \
                -p 443:443 \
                -v /opt/nginx-proxy-manager:/config \
                jc21/nginx-proxy-manager:latest
            ;;
        "webmin")
            local port=$((BASE_PORT_WEBSERVICES + RANDOM % 1000))
            echo -e "${GREEN}جاري تنصيب Webmin على المنفذ ${port}${NC}"
            docker run -d \
                --name=webmin \
                -p ${port}:10000 \
                -v /opt/webmin:/config \
                webmin/webmin:latest
            ;;
        "portainer")
            local port=$((BASE_PORT_WEBSERVICES + RANDOM % 1000))
            echo -e "${GREEN}جاري تنصيب Portainer على المنفذ ${port}${NC}"
            docker volume create portainer_data
            docker run -d \
                --name=portainer \
                -p ${port}:9000 \
                -v /var/run/docker.sock:/var/run/docker.sock \
                -v portainer_data:/data \
                portainer/portainer-ce:latest
            ;;
    esac
}

# الدالة الرئيسية
main() {
    check_root
    detect_distro
    
    # تنصيب المتطلبات الأساسية
    install_packages
    
    # عرض القائمة
    show_menu
    
    # معالجة الاختيار
    read -p "اختياراتك: " input
    if [ "$input" = "all" ]; then
        selected=("${SERVICES[@]}")
    else
        selected=()
        for choice in $input; do
            index=$((choice-1))
            if [ $index -ge 0 ] && [ $index -lt ${#SERVICES[@]} ]; then
                selected+=("${SERVICES[$index]}")
            fi
        done
    fi
    
    # تنصيب الخدمات المختارة
    for service in "${selected[@]}"; do
        if [ "$service" = "docker" ]; then
            echo -e "${GREEN}Docker مثبت بالفعل${NC}"
            continue
        fi
        
        if [ "$service" = "odoo" ]; then
            echo -e "${YELLOW}كم نسخة من أودو تريد تنصيبها؟${NC}"
            read odoo_count
            
            for ((i=1; i<=odoo_count; i++)); do
                echo -e "${YELLOW}اختر إصدار أودو للمثيل #$i (16/17/18):${NC}"
                read version
                if [[ " ${ODOO_VERSIONS[*]} " =~ " ${version} " ]]; then
                    install_odoo $i $version
                else
                    echo -e "${RED}إصدار غير صحيح!${NC}"
                    ((i--))
                fi
            done
        else
            install_service $service
        fi
    done
    
    # عرض الملخص
    echo -e "\n${GREEN}===================================${NC}"
    echo -e "${GREEN}     اكتمل التنصيب بنجاح!           ${NC}"
    echo -e "${GREEN}===================================${NC}"
    echo -e "${YELLOW}الخدمات المنصبة:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo -e "\n${GREEN}Elblasy.app - نظام احترافي لإدارة أودو${NC}"
}

# بدء التنفيذ
main
