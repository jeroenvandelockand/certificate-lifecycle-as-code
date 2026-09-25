apiVersion: apps/v1
kind: Deployment
metadata:
  name: clac-git-server
  namespace: argocd
  labels:
    app.kubernetes.io/name: clac-git-server
    app.kubernetes.io/part-of: certificate-lifecycle-as-code
spec:
  replicas: 1
  # Replacing the repository changes all Git object IDs. Recreate prevents an
  # in-flight Argo CD request from being routed to the old pod while it exits.
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: clac-git-server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: clac-git-server
    spec:
      automountServiceAccountToken: false
      securityContext:
        fsGroup: 65532
        fsGroupChangePolicy: OnRootMismatch
      initContainers:
        - name: unpack-repository
          image: __LOCAL_GIT_SERVER_IMAGE__
          imagePullPolicy: Never
          command:
            - /bin/sh
            - -ec
          args:
            - tar -xzf /bootstrap/repository.tar.gz -C /git
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            runAsNonRoot: true
            runAsUser: 65532
          volumeMounts:
            - name: repository-archive
              mountPath: /bootstrap
              readOnly: true
            - name: repository
              mountPath: /git
      containers:
        - name: git-daemon
          image: __LOCAL_GIT_SERVER_IMAGE__
          imagePullPolicy: Never
          command:
            - git
          args:
            - daemon
            - --reuseaddr
            - --base-path=/git
            - --export-all
            - --verbose
            - /git/repository.git
          ports:
            - name: git
              containerPort: 9418
          readinessProbe:
            tcpSocket:
              port: git
            initialDelaySeconds: 1
            periodSeconds: 2
          resources:
            requests:
              cpu: 5m
              memory: 16Mi
            limits:
              cpu: 100m
              memory: 64Mi
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            runAsNonRoot: true
            runAsUser: 65532
          volumeMounts:
            - name: repository
              mountPath: /git
              readOnly: true
      volumes:
        - name: repository-archive
          configMap:
            name: clac-git-repository
        - name: repository
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: clac-git
  namespace: argocd
  labels:
    app.kubernetes.io/name: clac-git-server
    app.kubernetes.io/part-of: certificate-lifecycle-as-code
spec:
  selector:
    app.kubernetes.io/name: clac-git-server
  ports:
    - name: git
      port: 9418
      targetPort: git
