-- Migração 001 — coluna de preço unitário.
--
-- RODE ISTO ANTES de instalar o APK novo. O app passou a enviar `preco`
-- em toda gravação; sem a coluna, salvar item dá erro.
--
-- Seguro para banco com dados: a coluna nasce NULL, e NULL quer dizer
-- "ninguém informou o preço" — diferente de 0, que seria "de graça".

ALTER TABLE items ADD COLUMN IF NOT EXISTS preco NUMERIC(10,2);

COMMENT ON COLUMN items.preco IS
  'Preço unitário em reais. NULL = não informado.';
