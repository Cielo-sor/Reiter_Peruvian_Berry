# Guía de captura y etiquetado

## Captura
- Fruta **cosechada** sobre **fondo liso y mate** (siempre el mismo), luz **difusa y constante**.
- Misma altura y ángulo (20–40 cm, de frente). Frutas **separadas**, sin taparse; 10–40 por foto.
- Incluir un **objeto de referencia de tamaño conocido** (regla/tarjeta) para medir calibre más adelante.
- Variar lotes, turnos, variedades y celulares. Incluir fruta sana y fruta con cada defecto.

## Etiquetado (fase actual: 2 clases)
1. **Un cuadro por fruta**, ajustado al borde, sin duplicados.
2. Cualquier defecto del póster de calidad/condición → `arandano_danado`. Sin defectos → `arandano_sano`.
3. **No** marcar "bajo calibre" como dañado (no se aprecia sin referencia de tamaño).
4. Ante la duda, consultar con control de calidad o dejar la fruta sin etiquetar.
5. Train y Valid deben tener **ambas** clases. Meta: 150+ cuadros por clase (prototipo), 500+ (uso real).

## Fase futura (clases por defecto, nombres exactos sin tildes)
- Condición: deshidratado, exudacion, pudricion, hongo, machucon, partidura
- Calidad: ausencia_bloom, bajo_calibre, cicatriz, dano_ave, desgarro, hendidura_pedicelar,
  inmaduro, russeting, suciedad, pedunculo_adherido, resto_floral, filodio
- El póster también incluye: presencia de insectos, blando y daño mecánico.
