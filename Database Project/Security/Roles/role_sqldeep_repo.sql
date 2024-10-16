CREATE ROLE [role_sqldeep_repo]
AUTHORIZATION [dbo]
GO
ALTER ROLE [role_sqldeep_repo] ADD MEMBER [AppCred_SqlDeepRepo]
GO
