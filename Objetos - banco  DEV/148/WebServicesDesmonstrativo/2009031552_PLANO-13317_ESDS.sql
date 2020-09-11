--<DS_SCRIPT>
-- DESCRIÇÃO..: Validação para login especifico da unimed brasil
-- RESPONSAVEL: Elias Silva
-- DATA.......: 03/09/2020
-- APLICAÇÃO..: MVS
--</DS_SCRIPT>
--<USUARIO=DBAPS>


CREATE OR REPLACE FUNCTION dbaps.fnc_mvs_valida_prestador_senha ( P_LOGIN_PRESTADOR IN VARCHAR2 DEFAULT NULL,
                                                                  P_SENHA_PRESTADOR IN VARCHAR2 DEFAULT NULL,
                                                                  P_SENHA_MD5 IN VARCHAR2 DEFAULT 'N',
                                                                  P_CD_MULTI_EMPRESA IN VARCHAR2 DEFAULT NULL ) return varchar2 IS
BEGIN
DECLARE
 /**************************************************************
    <objeto>
     <nome>prc_tiss_valida_cabecalho</nome>
     <usuario>Elias Silva</usuario>
     <alteracao>02/09/2020 09:45</alteracao>
     <ultimaAlteracao>Adicionado validação de senha UNIMED BRASIL </ultimaAlteracao>
     <descricao>Adicionado
                - Cursor para validação da senha de acesso para Unimed Brasil
     </descricao>
     <parametro></parametro>
     <tags>guia, importacao, xml</tags>
     <versao>1.11</versao>
     <soul>PLANO-13317</soul>
    </objeto>
  ***************************************************************/

CURSOR cPrestadorAutorizadores IS
  SELECT a.cd_autorizador, a.ds_senha
    FROM dbaps.prestador p,dbaps.prestador_endereco pe, dbaps.prestador_endereco_autorizador pea, dbaps.autorizador a
  WHERE p.cd_prestador = pe.cd_prestador
    AND pe.cd_prestador_endereco = pea.cd_prestador_endereco
    AND pea.cd_autorizador = a.cd_autorizador
    AND p.cd_prestador = REGEXP_REPLACE(P_LOGIN_PRESTADOR, '[^[:digit:]]+');

CURSOR cLoginUnimedBrasil IS
     SELECT valor login,
       (SELECT valor FROM   dbaps.mvs_configuracao
         WHERE  chave = 'TISS_SENHA_UNIMED'
               AND cd_multi_empresa = Nvl(P_CD_MULTI_EMPRESA,1)) senha
      FROM   dbaps.mvs_configuracao
      WHERE  chave = 'TISS_LOGIN_UNIMED'
      AND cd_multi_empresa = Nvl(P_CD_MULTI_EMPRESA,1);

-- variaveis regraNegocio
vSenhaValida  VARCHAR2(1) := 'N';
vSenhaMD5     VARCHAR2(100);

BEGIN

  vSenhaValida := 'N';

  --testando login especifico da unimed brasil
  FOR rLoginUnimedBrasil IN cLoginUnimedBrasil LOOP

      IF rLoginUnimedBrasil.login = P_LOGIN_PRESTADOR THEN

        /*IF  P_SENHA_MD5 = 'S' THEN
          vSenhaMD5 :=dbaps.fnc_calcula_md5(P_SENHA_PRESTADOR);
        END IF;*/

         IF vSenhaMD5 = rLoginUnimedBrasil.senha THEN
              vSenhaValida := 'S';
          END IF;

      END IF;

  END LOOP;

  IF vSenhaValida= 'S' THEN
   RETURN vSenhaValida;
  END IF;

  --testando login no cadastro do prestador
  FOR rPrestadorAutorizadores IN cPrestadorAutorizadores LOOP

    -- verifica hashs MD5
    IF P_SENHA_MD5 = 'S' THEN
        vSenhaMD5 := dbaps.fnc_calcula_md5(rPrestadorAutorizadores.ds_senha);
        IF(vSenhaMD5 = P_SENHA_PRESTADOR) THEN
          vSenhaValida := 'S';
        END IF;
    ELSE -- verifica senha PLANA
      IF(rPrestadorAutorizadores.ds_senha = P_SENHA_PRESTADOR) THEN
        vSenhaValida := 'S';
      END IF;

    END IF;


  END LOOP;

  Return vSenhaValida;

END;
End fnc_mvs_valida_prestador_senha;
/

GRANT EXECUTE ON dbaps.fnc_mvs_valida_prestador_senha TO dbamv
/
GRANT EXECUTE ON dbaps.fnc_mvs_valida_prestador_senha TO dbasgu
/
GRANT EXECUTE ON dbaps.fnc_mvs_valida_prestador_senha TO mv2000
/
GRANT EXECUTE ON dbaps.fnc_mvs_valida_prestador_senha TO mvintegra
/
