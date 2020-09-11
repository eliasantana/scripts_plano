PROMPT CREATE OR REPLACE PROCEDURE dbaps.confirma_item_ressarc_sus_sn
CREATE OR REPLACE PROCEDURE dbaps.confirma_item_ressarc_sus_sn(P_SN_CONFIRMAR IN VARCHAR2) AS

cont NUMBER;

BEGIN
cont := 0;


FOR R IN (
        SELECT cd_item_ress_sus_anexo FROM dbaps.tmp_cd_ressarcimento_sus_anexo
) LOOP


UPDATE DBAPS.ITEM_RESSARCIMENTO_SUS_ANEXO SET SN_CONFIRMAR = P_SN_CONFIRMAR
WHERE CD_ITEM_RESSARCIMENT_SUS_ANEXO = r.cd_item_ress_sus_anexo;

cont := cont +1;

    IF cont = 1000 then
      COMMIT;
      cont := 0;
    END IF;

END LOOP;

COMMIT;

DELETE FROM  dbaps.tmp_cd_ressarcimento_sus_anexo;

COMMIT;

END;
/

