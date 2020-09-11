--<DS_SCRIPT>
-- DESCRIÇÃO..: Alterar validacao da conta de evento conhecido
-- como a conta de glosa
-- RESPONSAVEL: Paulo Gustavo
-- DATA.......: 08/02/2020
-- APLICAÇÃO..: MVS
--</DS_SCRIPT>
--<USUARIO=DBAPS>

CREATE OR REPLACE TRIGGER dbaps.trg_mvsaude_fcct_despesa
BEFORE INSERT  OR DELETE  OR UPDATE
ON dbaps.mvsaude_fcct_despesa
REFERENCING NEW AS NEW OLD AS OLD
FOR EACH ROW

 /**************************************************************
    <objeto>
	<nome>TRG_CONFIG_RATEIO_CUSTO</nome>
     <usuario>Paulo Gustavo</usuario>
     <alteracao>08/02/2020 15:44</alteracao>
     <descricao>Alterar validacao da conta de evento conhecido como a conta de glosa</descricao>
    <parametro></parametro>
    <versao>1.2</versao>
  <tags>Contabilidade</tags>
    </objeto>
  ***************************************************************/

DECLARE
  CURSOR cChk (PCD_REDUZIDO IN NUMBER) IS
    SELECT pc_ec.cd_contabil cd_ctb_evento,
           pc_re.cd_contabil cd_ctb_glosa
      FROM dbamv.plano_contas pc_ec,
           dbamv.plano_contas pc_re
      WHERE pc_ec.cd_reduzido(+) = :NEW.CD_REDUZIDO_EVENTO_CONHECIDO
        AND pc_re.cd_reduzido(+) = PCD_REDUZIDO
        AND SubStr( REPLACE( pc_ec.cd_contabil, '.', '' ), 1, 6 ) <> SubStr( REPLACE( pc_re.cd_contabil, '.', '' ), 1, 6 );
  cCtbEvento VARCHAR2(2000);
  cCtbGlosa  VARCHAR2(2000);

BEGIN
  IF NOT DELETING THEN
    IF :NEW.CD_MULTI_EMPRESA IS NULL THEN
      :NEW.CD_MULTI_EMPRESA := DBAMV.PKG_MV2000.LE_EMPRESA;
    END IF;
  END IF;
  IF INSERTING OR UPDATING THEN
    IF :NEW.CD_REDUZIDO_EVENTO_CONHECIDO <> Nvl( :OLD.CD_REDUZIDO_EVENTO_CONHECIDO, :NEW.CD_REDUZIDO_EVENTO_CONHECIDO ) THEN
      IF :NEW.CD_REDUZIDO_RE <> Nvl( :OLD.CD_REDUZIDO_RE, :NEW.CD_REDUZIDO_RE ) THEN
        cCtbEvento := NULL;
        cCtbGlosa := NULL;
        OPEN  cChk (:NEW.CD_REDUZIDO_RE);
        FETCH cChk INTO cCtbEvento, cCtbGlosa;
        IF cChk%FOUND THEN
          Raise_Application_Error( -20010, 'O grupo de conta contábil da conta de recuperação por glosa (' || cCtbGlosa || ') diverge do grupo de conta contábil de evento conhecido (' || cCtbEvento || ').' );
        END IF;
        CLOSE cChk;
      END IF;
      IF :NEW.CD_REDUZIDO_CR <> Nvl( :OLD.CD_REDUZIDO_CR, :NEW.CD_REDUZIDO_CR ) THEN
        cCtbEvento := NULL;
        cCtbGlosa := NULL;
        OPEN  cChk (:NEW.CD_REDUZIDO_RE);
        FETCH cChk INTO cCtbEvento, cCtbGlosa;
        IF cChk%FOUND THEN
          Raise_Application_Error( -20010, 'O grupo de conta contábil da conta de recuperação por franquia (' || cCtbGlosa || ') diverge do grupo de conta contábil de evento conhecido (' || cCtbEvento || ').' );
        END IF;
        CLOSE cChk;
      END IF;
    END IF;
    IF :new.cd_setor IS NULL THEN
      Raise_Application_Error( -20007, 'Setor não foi informado!' );
    END IF;
    IF :new.dt_vigencia IS NULL THEN
      Raise_Application_Error( -20008, 'Vigência não informada!' );
    END IF;
    IF :NEW.cd_reduzido_evento_conhecido IS NOT NULL THEN
        IF dbaps.fnc_confere_multi_empresa('cd_reduzido', :NEW.cd_reduzido_evento_conhecido, :NEW.cd_multi_empresa ) = 0 THEN
          Raise_Application_Error(-20001, 'Evento Conhecido com operadora diferente no FNFI! ' || :NEW.cd_reduzido_evento_conhecido);
        END IF;
    ELSE
      Raise_Application_Error( -20006, 'Conta de evento conhecido não informada!' );
    END IF;
    IF :NEW.cd_reduzido_re IS NOT NULL THEN
        IF dbaps.fnc_confere_multi_empresa('cd_reduzido', :NEW.cd_reduzido_re, :NEW.cd_multi_empresa ) = 0 THEN
          Raise_Application_Error(-20002, 'Recuperação de Evento com operadora diferente no FCCT! ');
        END IF;
    ELSE
      Raise_Application_Error( -20009, 'Conta de recuperação de evento não informada!' );
    END IF;
    IF :NEW.cd_reduzido_cr IS NOT NULL THEN
        IF dbaps.fnc_confere_multi_empresa('cd_reduzido', :NEW.cd_reduzido_cr, :NEW.cd_multi_empresa ) = 0 THEN
          Raise_Application_Error(-20003, 'Co-Responsabilidade com operadora diferente no FCCT! ');
        END IF;
    END IF;
    IF :NEW.cd_setor IS NOT NULL THEN
        IF dbaps.fnc_confere_multi_empresa('cd_setor', :NEW.cd_setor, :NEW.cd_multi_empresa ) = 0 THEN
          Raise_Application_Error(-20004, 'Setor com operadora diferente no FCCT! ' || :NEW.cd_setor);
        END IF;
    END IF;
    IF :NEW.cd_plano IS NOT NULL THEN
        IF dbaps.fnc_confere_multi_empresa('cd_plano', :NEW.cd_plano, :NEW.cd_multi_empresa ) = 0 THEN
          Raise_Application_Error(-20005, 'Plano de outra operadora! ');
        END IF;
    END IF;
  END IF;
END;
/