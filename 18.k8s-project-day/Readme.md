# K8S Final Project

Yêu cầu của bài tập là thực hiện triển khai một ứng dụng gồm frontend kết nối tới backend qua json api, và backend kết nối với mysql database (có dữ liệu khởi tạo)

Bài tập được thiết kế dưới dạng 1 course, step by step theo các bài học. Tuy nhiên việc trình bày kết quả theo từng thành phần bài học không khác gì việc dịch lại hướng dẫn, bên cạnh đó từng phần thì kết quả chạy vẫn lỗi do chưa đầy đủ và được cập nhật tiếp ở bài sau. 

Do vậy mình trình bày kết quả sau khi hoàn thành dưới dạng tổng hợp theo các nhiệm vụ

Dự án gồm các nhiệm vụ:

1. Đóng gói các image
    1. Đóng gói image k8scourse-back và đẩy lên docker hub buiduckhanh1986/k8scourse-back
	2. Đóng gói image k8scourse-front và đẩy lên docker hub buiduckhanh1986/k8scourse-front
	
2. Triển khai trên môi trường docker
	
3. Triển khai trên môi trường K8s


## Phần 1: Đóng gói các image

### 1.1 Đóng gói k8scourse-back

Sửa config.js và apiKey.js trong thư mục back để nhận giá trị từ biến môi trường

```
const config = {
  MYSQL_HOST: process.env.MYSQL_HOST || "localhost",
  MYSQL_USER: process.env.MYSQL_USER || "root",
  MYSQL_PASS: process.env.MYSQL_PASS || "root",
  MYSQL_DB: process.env.MYSQL_DB || "images",
  IMAGE_PATH: process.env.IMAGE_PATH || "/tmp",
  GIF_CAPTION_SVC: process.env.GIF_CAPTION_SVC || "localhost:4000"
}

module.exports = config;
```

```
const giphyKey = "XdH4LFG7cQeNiS3D6M1rVBYWee3j3hG6";

module.exports = {
  "GIPHY": giphyKey
}
```

Viết Dockerfile để trong thư mục back

```
# Dockerfile
FROM node:14
WORKDIR /app
RUN mkdir tmp
RUN mkdir assets
COPY ./package*.json /app/
RUN npm install
COPY *.js /app/
COPY assets/* /app/assets/
COPY tmp /app/
CMD ["node", "/app"]
```

Build image buiduckhanh1986/k8scourse-back
```
docker build -t buiduckhanh1986/k8scourse-back .
```

Đẩy image buiduckhanh1986/k8scourse-back lên docker hub


### 1.2 Đóng gói k8scourse-front

Sửa config.json hư mục front/src để nhận giá trị từ biến môi trường
```
{
  "BASE_URL": "$BASE_URL"
}
```

Tạo file start_nginx.sh để trong thư mục front để đảm bảo nó thay hết BASE_URL trong các file js và khởi động nginx
```
#!/usr/bin/env bash
for file in /usr/share/nginx/html/js/app.*.js;
do
 if [ ! -f $file.tmp.js ]; then
   cp $file $file.tmp.js
 fi
 envsubst '$BASE_URL' < $file.tmp.js > $file
done
nginx -g 'daemon off;'
```


Viết Dockerfile để trong thư mục front

```
# Dockerfile
FROM node:14 AS builder
COPY . /app
WORKDIR /app/src
RUN sed -i 's/http:\/\/localhost:3000/\$BASE_URL/' config.json
WORKDIR /app
RUN npm install
RUN npm run build

FROM nginx:1.17
WORKDIR /usr/share/nginx/html
COPY --from=builder /app/dist .
COPY start_nginx.sh /
RUN chmod +x /start_nginx.sh
ENTRYPOINT ["/start_nginx.sh"]
```

Build image buiduckhanh1986/k8scourse-front

```
docker build -t buiduckhanh1986/k8scourse-front .
```

Đẩy image buiduckhanh1986/k8scourse-front lên docker hub


## Phần 2: Triển khai trên docker

### 2.1 Tạo network k8scourse

Tạo network k8scourse dạng bridge để có thể tận dụng kết nối qua tên của container

```
docker network create -d bridge k8scourse
```

### 2.2 Triển khai k8scourse-db

Ở đây cần image mysql bản 5.7 (tránh lỗi old authentication, bản mới cần cập nhật cơ chế auth mới của mysql phức tạp hơn mà không cẩn thiết) và có dữ liệu khởi tạo

Bước 1: copy thư mục db chứa init.sql vào thư mục hiện hành

```
create database if not exists images;
use images;
create table images( id INT AUTO_INCREMENT PRIMARY KEY, caption VARCHAR(100), filename VARCHAR(255) );
insert into images(caption, filename) values("Hello", "01.png");
```

Bước 2: Tạo db từ image mysql:5.7 mật khẩu root là root, mount file init.sql vào để khởi tạo db và kết nối vào network k8scourse, option --rm để xóa giải phóng tài nguyên khi ngừng container kết thúc bài test

```
docker run -p 3306:3306 -d --rm --name k8scourse-db -e MYSQL_ROOT_PASSWORD=root -v $(pwd)/db/init.sql:/docker-entrypoint-initdb.d/init.sql --network k8scourse mysql:5.7
```


## 2.3 Triển khai k8scourse-back

Tạo backend từ image buiduckhanh1986/k8scourse-back kết nối vào network k8scourse, kết nối với db ở host k8scourse-db, user root mật khẩu root, mở cổng 3000 cho backend, option --rm để xóa giải phóng tài nguyên khi ngừng container kết thúc bài test

```
docker run -p 3000:3000 --name k8scourse-back -d --rm --network k8scourse -e MYSQL_HOST=k8scourse-db -e MYSQL_USER=root -e MYSQL_PASS=root -d buiduckhanh1986/k8scourse-back
```

Môi trường triển khai ở đây là máy ảo VM có địa chỉ 127.0.0.87, vì front end sẽ kết nối vào back end dưới dạng json api từ trình duyệt do đó BASE_URL để kết nối vào back end sẽ phải là

```
BASE_URL=http://127.0.0.87:3000
```

## 2.4 Triển khai k8scourse-front

Tạo backend từ image buiduckhanh1986/k8scourse-back kết nối vào network k8scourse, thiết lập base url của backend là http://127.0.0.87:3000, option --rm để xóa giải phóng tài nguyên khi ngừng container kết thúc bài test

```
docker run -d --rm --name k8scourse-front -p 8888:80 -e BASE_URL=http://127.0.0.87:3000 --network k8scourse buiduckhanh1986/k8scourse-front
```

## Phần 3: Triển khai trên K8s

### 3.1 Triển khai db

Tạo PersistentVolume mysql-pv và PersistentVolumeClaim mysql-pvc để lưu trữ dữ liệu db
```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-pv
spec:
  capacity:
    storage: 200Mi
  accessModes:
    - ReadWriteOnce 
  hostPath:
    path: "/mnt/data"
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 200Mi
```

Lệnh tạo 
```
kubectl apply -f pv-pvc.yaml
```

Tạo deployment k8scourse-db triển khai 1 pod dùng image mysql:5.7, thiết lập root password là root dùng PersistentVolumeClaim mysql-pvc để chứa dữ liệu, dùng ConfigMap initdb đẩy vào /docker-entrypoint-initdb.d để seed data cho db (ở đây lệnh sql ngắn dùng ConfigMap cho tiện). Đồng thời tạo Service ClusterIP k8scourse-db làm điểm kết nối

```
apiVersion: v1
kind: Service
metadata:
  name: k8scourse-db
spec:
  ports:
  - port: 3306
  selector:
    role: db
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8scourse-db
spec:
  selector:
    matchLabels:
      role: db
  template:
    metadata:
      labels:
        app: k8scourse
        role: db
    spec:
      containers:
      - image: mysql:5.7
        name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: root
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
        - name: initdb
          mountPath: /docker-entrypoint-initdb.d
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: mysql-pvc
      - name: initdb
        configMap:
          name: initdb-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: initdb-config
data:
  initdb.sql: |
      create database if not exists images;
      use images;
      create table images( id INT AUTO_INCREMENT PRIMARY KEY, caption VARCHAR(100), filename VARCHAR(255) );
      insert into images(caption, filename) values("Hello", "01.png");
```

Lệnh tạo 
```
kubectl apply -f database.yaml
```

### 3.2 Triển khai backend

Tạo deployment k8scourse-back triển khai 2 pod dùng image buiduckhanh1986/k8scourse-back, thiết lập biến môi trường kết nối vào db ở service k8scourse-db, với user root, password root. Đồng thời mở 1 Service ClusterIP k8scourse-back làm điểm kết nối

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8scourse-back
  labels:
    app: k8scourse-demo
    role: backend
spec:
  template:
    metadata:
      labels:
        app: k8scourse-demo
        role: backend
    spec:
      containers:
      - name: api
        image: buiduckhanh1986/k8scourse-back
        env:
        - name: MYSQL_HOST
          value: k8scourse-db
        - name: MYSQL_USER
          value: root
        - name: MYSQL_PASS
          value: root
  selector:
    matchLabels:
      role: backend
  replicas: 2
---
apiVersion: v1
kind: Service
metadata:
  name: k8scourse-back
  labels:
    role: backend
spec:
  selector:
    role: backend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 3000
```

Lệnh tạo 
```
kubectl apply -f backend.yaml
```


### 3.3 Triển khai frontend

IP hiện tại của cụm minikube là 192.168.49.2 ta sẽ tạo 1 Ingress để config
    1. http://192.168.49.2/api : đường dẫn này sẽ map vào backend và là json api cho front end kết nối
	2. http://192.168.49.2 đường dẫn này sẽ là dùng để truy cập frontend
	
Tuy nhiên trước khi tạo Ingress chúng ta sẽ tạo deployment k8scourse-front triển khai frontend dùng image buiduckhanh1986/k8scourse-front với base url http://192.168.49.2/api ( như định nghĩa ingress ở trên ) và mở 1 Service ClusterIP k8scourse-back làm điểm kết nối

Deployment k8scourse-front

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8scourse-front
  labels:
    app: k8scourse-demo
    role: frontend
spec:
  template:
    metadata:
      labels:
        app: k8scourse-demo
        role: frontend
    spec:
      containers:
      - name: server
        image: buiduckhanh1986/k8scourse-front
        env:
        - name: BASE_URL
          value: http://192.168.49.2/api
  selector:
    matchLabels:
      role: frontend
  replicas: 2
---
apiVersion: v1
kind: Service
metadata:
  name: k8scourse-front
  labels: 
    role: frontend
spec:
  selector:
    role: frontend
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

Ingress để public các api

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: main
  annotations:
   nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  rules:
  - http:
      paths:
        - path: /api(/|$)(.*)
          pathType: Prefix
          backend:
            service:
              name: k8scourse-back
              port:
               number: 80
        - path: /()(.*)
          pathType: ImplementationSpecific
          backend:
            service:
              name: k8scourse-front
              port:
               number: 80
```

Lệnh tạo 
```
kubectl apply -f frontend.yaml

kubectl apply -f ingress.yaml
```
