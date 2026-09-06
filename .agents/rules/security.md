# Regras de Segurança do Repositório (AppSec)

- **Repositório Público**: Todo o código é público no GitHub.
- **Proibição Estrita de Segredos**: Nunca inserir senhas reais, `service_role_key`, tokens JWT privados, chaves de API restritas ou credenciais no código.
- **Auditoria Pré-Git**: Nunca executar ou sugerir `git commit` ou `git push` sem verificar previamente que nenhum dado confidencial ou arquivo sensível (`.env`, `google-services.json`, `.jks`, `.keystore`) está sendo commitado.
