## Deploy Light-oauth2 on Kubernetes.

1. Light-oauth2 use Hazelcast for sharing data betweent services. When deploy light-oauth2 on Kubernetes, application have to "hazelcast.xml" configure file inside "config" folder.


```xml
....

    <properties>
        <property name="hazelcast.discovery.enabled">true</property>
    </properties>

...
...
    <!--
        This defile how Hazelcast find members.
    -->
    <kubernetes enabled="true">
        <namespace>default</namespace>
        <service-name>hazelcast-service</service-name>
    </kubernetes>    
.....
.....
```

2. Define Hazelcast Headless Service

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

3. Modify deployment.yaml to configure Hazelcast port. Hazelcast members communicate over a specific port (default 5701). If your app configures Hazelcast to use 5710, you must:

- Update hazelcast.xml
```xml
<network>
  <port>5710</port> <!-- Explicitly set Hazelcast port -->
</network>
```

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

4. Configure RBAC for Service Account
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