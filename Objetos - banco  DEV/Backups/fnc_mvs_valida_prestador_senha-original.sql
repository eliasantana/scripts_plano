PROMPT CREATE OR REPLACE FUNCTION dbaps.fnc_mvs_valida_prestador_senha
CREATE OR REPLACE FUNCTION dbaps.fnc_mvs_valida_prestador_senha ( P_LOGIN_PRESTADOR IN NUMBER DEFAULT NULL, P_SENHA_PRESTADOR IN VARCHAR2 DEFAULT NULL, P_SENHA_MD5 IN VARCHAR2 DEFAULT 'N') return varchar2 IS
BEGIN
DECLARE
CURSOR cPrestadorAutorizadores IS
  SELECT a.cd_autorizador, a.ds_senha
    FROM dbaps.prestador p,dbaps.prestador_endereco pe, dbaps.prestador_endereco_autorizador pea, dbaps.autorizador a
  WHERE p.cd_prestador = pe.cd_prestador
    AND pe.cd_prestador_endereco = pea.cd_prestador_endereco
    AND pea.cd_autorizador = a.cd_autorizador
    AND p.cd_prestador = P_LOGIN_PRESTADOR;
-- variaveis regraNegocio
vSenhaValida  VARCHAR2(1) := 'N';
vSenhaMD5     VARCHAR2(100);
BEGIN
  vSenhaValida := 'N';
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

GRANT EXECUTE ON dbaps.fnc_mvs_valida_prestador_senha TO dbamv;
GRANT EXECUTE ON dbaps.fnc_mvs_valida_prestador_senha TO dbasgu;
GRANT EXECUTE ON dbaps.fnc_mvs_valida_prestador_senha TO mv2000;
GRANT EXECUTE ON dbaps.fnc_mvs_valida_prestador_senha TO mvintegra;
