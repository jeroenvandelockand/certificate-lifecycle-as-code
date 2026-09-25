apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: certificate-platform
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: "__REPO_URL__"
    targetRevision: "__TARGET_REVISION__"
    path: gitops/root
    helm:
      parameters:
        - name: global.repoURL
          value: "__REPO_URL__"
        - name: global.targetRevision
          value: "__TARGET_REVISION__"
        - name: versions.certManager
          value: "__CERT_MANAGER_VERSION__"
        - name: versions.approverPolicy
          value: "__APPROVER_POLICY_VERSION__"
        - name: images.demoApp
          value: "__DEMO_APP_IMAGE__"
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true

