# Triển Khai Light-OAuth2 Trên Kubernetes

Tài liệu này hướng dẫn cách triển khai ứng dụng Light-OAuth2 và các thành phần phụ thuộc trên cụm Kubernetes bằng Helm. Hướng dẫn bao gồm cấu hình Hazelcast cho chia sẻ dữ liệu phân tán, các dịch vụ cần thiết trên Kubernetes và thiết lập quyền RBAC.

---

## Mục Lục
- [Triển Khai Light-OAuth2 Trên Kubernetes](#triển-khai-light-oauth2-trên-kubernetes)
  - [Mục Lục](#mục-lục)
  - [Tóm tắt](#tóm-tắt)
  - [Yêu cầu](#yêu-cầu)
  - [Các bước triển khai](#các-bước-triển-khai)
    - [1. Cấu hình Hazelcast](#1-cấu-hình-hazelcast)
    - [2. Khai báo Headless Service cho Hazelcast](#2-khai-báo-headless-service-cho-hazelcast)
    - [3. Cập nhật deployment.yaml](#3-cập-nhật-deploymentyaml)
    - [4. Thiết lập RBAC](#4-thiết-lập-rbac)
  - [Ví dụ triển khai với Helm](#ví-dụ-triển-khai-với-helm)

---

## Tóm tắt
- Light-OAuth2 sử dụng Hazelcast để cache và chia sẻ dữ liệu giữa các service.
- Hazelcast cần được cấu hình đúng để phát hiện các node trên Kubernetes.
- Cần tạo headless service và mở các port cần thiết.
- Cần thiết lập quyền RBAC để Hazelcast có thể phát hiện các thành viên trong cluster.

## Yêu cầu
- Có cụm Kubernetes đang chạy (khuyến nghị v1.16+)
- Đã cài đặt và cấu hình `kubectl`
- Đã cài đặt [Helm](https://helm.sh/) (phiên bản 3 trở lên)
- Namespace (mặc định: `default`) và các service account như bên dưới

---

## Các bước triển khai

### 1. Cấu hình Hazelcast
Cập nhật file `hazelcast.xml` (trong thư mục `config`) để bật tính năng phát hiện trên Kubernetes:

```xml
<properties>
    <property name="hazelcast.discovery.enabled">true</property>
</properties>
...
<kubernetes enabled="true">
    <namespace>default</namespace>
    <service-name>hazelcast-service</service-name>
</kubernetes>
```

### 2. Khai báo Headless Service cho Hazelcast
Tạo một headless service cho Hazelcast trên Kubernetes:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: hazelcast-service
  namespace: default
spec:
  clusterIP: None
  selector:
    app: light-oauth2
  ports:
  - name: hazelcast
    port: 5701
```

### 3. Cập nhật deployment.yaml
Đảm bảo file `deployment.yaml` mở port Hazelcast (mặc định: 5701). Nếu dùng port khác (vd: 5710), cần cập nhật cả `hazelcast.xml` và service tương ứng:

**hazelcast.xml**
```xml
<network>
  <port>5710</port> <!-- Thiết lập port Hazelcast rõ ràng -->
</network>
```

**deployment.yaml**
```yaml
ports:
  - name: hazelcast
    containerPort: 5701 # Phải trùng với port của Hazelcast
    protocol: TCP
  - name: http
    containerPort: {{ .Values.service.containerPort }}
    protocol: TCP
```

**hazelcast-service.yaml (nếu dùng port tùy chỉnh):**
```yaml
spec:
  ports:
  - port: 5710 # Service port
    targetPort: 5710 # Map tới containerPort:5710 trong pod
```

### 4. Thiết lập RBAC
Hazelcast cần quyền để phát hiện các thành viên trong cluster. Áp dụng các resource RBAC sau:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: hazelcast-cluster-role
rules:
  - apiGroups: ["", apps]
    resources: [endpoints, pods, nodes, services, statefulsets]
    verbs: [get, list, watch]
  - apiGroups: ["discovery.k8s.io"]
    resources: [endpointslices]
    verbs: [get, list]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: hazelcast-cluster-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: hazelcast-cluster-role
subjects:
  - kind: ServiceAccount
    name: default
    namespace: default
  - kind: ServiceAccount
    name: light-oauth2-code
    namespace: default
  - kind: ServiceAccount
    name: light-oauth2-token
    namespace: default
```

---

## Ví dụ triển khai với Helm

Để triển khai các service Light-OAuth2 bằng Helm:

```sh
helm upgrade --install light-oauth2-token ./light-oauth2-token -f ./light-oauth2-token/dev-values.yaml
```
---

Tham khảo thêm ở các thư mục chart thành phần và các file cấu hình ví dụ.


- Update deployment.yaml:
```yaml
          ports:
            - name: hazelcast
              containerPort: 5701 # Must match Hazelcast's port
              protocal: TCP
            - name: http
              containerPort: {{ .Values.service.containerPort }}
              protocol: TCP
```

- Update hazelcast-service.yaml:
```yaml
spec:
  ports:
  - port: 5710 # Service port
    targetPort: 5710 # Maps to containerPort:5710 in pods
```

1. Configure RBAC for Service Account
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: hazelcast-cluster-role
rules:
  - apiGroups:
      - ""
      - apps
    resources:
      - endpoints
      - pods
      - nodes
      - services
      - statefulsets
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - "discovery.k8s.io"
    resources:
      - endpointslices
    verbs:
      - get
      - list
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: hazelcast-cluster-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: hazelcast-cluster-role
subjects:
  - kind: ServiceAccount
    name: default
    namespace: default
  - kind: ServiceAccount
    name: light-oauth2-code
    namespace: default
  - kind: ServiceAccount
    name: light-oauth2-token
    namespace: default
```


helm install light-oauth2-client ./helms/light-oauth2-client -f ./helms/light-oauth2-client/dev-values.yaml
helm install light-oauth2-key ./helms/light-oauth2-key -f ./helms/light-oauth2-key/dev-values.yaml
helm install light-oauth2-refresh-token ./helms/light-oauth2-refresh-token -f ./helms/light-oauth2-refresh-token/dev-values.yaml
helm install light-oauth2-service ./helms/light-oauth2-service -f ./helms/light-oauth2-service/dev-values.yaml
helm install light-oauth2-token ./helms/light-oauth2-token -f ./helms/light-oauth2-token/dev-values.yaml
helm install light-oauth2-user ./helms/light-oauth2-user -f ./helms/light-oauth2-user/dev-values.yaml
helm install light-oauth2-code ./helms/light-oauth2-code -f ./helms/light-oauth2-code/dev-values.yaml

helm uninstall light-oauth2-client
helm uninstall light-oauth2-key
helm uninstall light-oauth2-refresh-token
helm uninstall light-oauth2-service
helm uninstall light-oauth2-token
helm uninstall light-oauth2-user
helm uninstall light-oauth2-code


curl -k -v -H 'Authorization: BASIC YWRtaW46MTIzNDU2' 'https://light-oauth2-code:6881/oauth2/code?response_type=code&client_id=f7d42348-c647-4efb-a52d-4c5787421e72&redirect_uri=http://localhost:8080/authorization'


curl -k -H "Authorization: Basic f7d42348-c647-4efb-a52d-4c5787421e72:f6h1FTI8Q3-7UScPZDzfXA" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -X POST \
  -d "grant_type=authorization_code&code=7tQTLoJaRUGvxF2B1MulIg&redirect_uri=http://localhost:8080/authorization" \
  https://light-oauth2-token:6882/oauth2/token