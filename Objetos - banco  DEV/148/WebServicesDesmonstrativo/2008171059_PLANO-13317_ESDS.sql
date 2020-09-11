--<DS_SCRIPT>
-- DESCRIÇÃO..: Criação de chave TISS_LOGIN_UNIMED
-- RESPONSAVEL: Elias Silva
-- DATA.......: 17/08/2020
-- APLICAÇÃO..: MVS
--</DS_SCRIPT>
--<USUARIO=DBAPS>


BEGIN
  FOR rMultiEmpresa IN (SELECT CD_MULTI_EMPRESA FROM DBAMV.MULTI_EMPRESAS_MV_SAUDE)
  LOOP
    INSERT INTO DBAPS.MVS_CONFIGURACAO (cd_multi_empresa
                                       , ds_configuracao
                                       , chave
                                       , valor
									                     , TP_TIPO)
      VALUES (rMultiEmpresa.cd_multi_empresa,
               'LOGIN DE ACESSO AOS WEBSERVICES TISS PARA UNIMED BRASIL',
               'TISS_LOGIN_UNIMED',
               'unimedbrasil',
			         'V');
	COMMIT;

  END LOOP;

  COMMIT;

END;
/