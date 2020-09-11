PROMPT CREATE OR REPLACE PROCEDURE dbaps.confirma_item_ressarc_sus_sn
CREATE OR REPLACE PROCEDURE dbaps.confirma_item_ressarc_sus_sn(P_SN_CONFIRMAR IN VARCHAR2, P_CD_USUARIO IN VARCHAR2) AS

cont NUMBER;

BEGIN

/**************************************************************
    <objeto>
     <nome>confirma_item_ressarc_sus_sn</nome>
     <usuario>Elias Santana</usuario>
     <descricao>Procedure chamada na Tela M_RESSARCIMENTO_SUS, a ser executada através dos botões MARCAR TODOS e DESMARCAR TODOS. </descricao>
     <funcionalidade>Auxiliar no UPDATE massivo para os itens do Ressarcimento Sus Anexo</funcionalidade>
     <parametro>
       P_SN_CONFIRMAR - S-Processa Reembolso  N-Ignora Reembolso
       P_CD_USUARIO -   Usuário Logado
  	 </parametro>
     <tags>Contabilidade</tags>
     <versao>1.0</versao>
    </objeto>
**************************************************************/


cont := 0;


FOR R IN (
        SELECT cd_item_ress_sus_anexo, cd_usuario FROM dbaps.tmp_cd_ressarcimento_sus_anexo
) LOOP


UPDATE DBAPS.ITEM_RESSARCIMENTO_SUS_ANEXO SET SN_CONFIRMAR = P_SN_CONFIRMAR
WHERE CD_ITEM_RESSARCIMENT_SUS_ANEXO = r.cd_item_ress_sus_anexo AND r.cd_usuario = p_cd_usuario;

cont := cont +1;

    IF cont = 1000 then
      COMMIT;
      cont := 0;
    END IF;

END LOOP;

COMMIT;

DELETE FROM  DBAPS.TMP_CD_RESSARCIMENTO_SUS_ANEXO WHERE CD_USUARIO = P_CD_USUARIO;

COMMIT;

END;


