CREATE OR REPLACE FUNCTION DBAPS.FNC_MVS_RETORNO_DS_CONTA( pcd_contabil VARCHAR2, pcd_reduzido IN NUMBER, pdt_referencia IN DATE ) RETURN VARCHAR2 IS

CURSOR C IS
  SELECT PE.DS_CONTA
    FROM DBAMV.PLANO_ESTR PE, DBAMV.MES_ANO_FECH_CONT MA
    WHERE CD_CONTABIL = '1.2.1'
      AND PE.CD_PLANO = MA.CD_PLANO
      AND (PE.CD_CONTABIL = pcd_contabil OR PE.CD_REDUZIDO = pcd_reduzido )
      AND MA.CD_MULTI_EMPRESA = DBAMV.PKG_MV2000.LE_EMPRESA
      AND TRUNC(MA.DT_ANO,'YYYY') = TRUNC(PDT_REFERENCIA, 'YYYY')
      AND MA.DT_MES = TO_CHAR(PDT_REFERENCIA, 'MM');

CURSOR cPC IS
  SELECT DS_CONTA
    FROM DBAMV.PLANO_CONTAS PC
    WHERE PC.CD_MULTI_EMPRESA = DBAMV.PKG_MV2000.LE_EMPRESA
      AND (PC.CD_CONTABIL = pcd_contabil OR PC.CD_REDUZIDO = pcd_reduzido );

cDsConta VARCHAR2(2000);

BEGIN
  cDsConta := '';

  OPEN  C;
  FETCH C INTO cDsConta;

  IF C%NOTFOUND THEN
    OPEN  cPC;
    FETCH cPC INTO cDsConta;
    CLOSE cPC;
  END IF;

  CLOSE C;

  RETURN Nvl(cDsConta, 'NAO ENCONTRADO' );
END;

