# Como contornamos as limitações do GPS para melhorar a precisão dos tempos

O GPS do celular não é perfeito. No Samsung A35 — e na maioria dos smartphones — o sinal oscila entre 5 e 10 metros em condições normais. Para um app de cronometragem de kart onde a linha de chegada tem menos de 10 metros de largura, isso significa que o celular pode "achar" que você cruzou a linha antes ou depois de ter cruzado de verdade.

Aqui estão os quatro problemas que identificamos e como resolvemos cada um.

---

## Problema 1: o GPS coloca você do lado errado da linha

**O que acontecia:** O app detecta a passagem pela linha de largada ou setor calculando de qual lado do traçado o celular está. Quando o GPS erra 5–10m, ele pode colocar o celular do lado "correto" antes de você ter realmente cruzado, ou no lado "errado" por alguns instantes depois de já ter cruzado.

**Como resolvemos:** Adicionamos uma tolerância de 5m nas extremidades da linha. Na prática, o app aceita que você "cruzou" mesmo que o GPS ainda esteja ligeiramente fora do segmento exato. Isso compensa a imprecisão sem inventar cruzamentos falsos.

---

## Problema 2: o GPS oscilando longe do setor mudava o estado interno errado

**O que acontecia:** O app precisa lembrar de qual lado da linha de setor você estava antes de cruzar — para saber quando houve de fato uma mudança de lado. O problema é que, quando você está longe do setor (por exemplo, na reta do lado oposto da pista), o GPS oscilando podia registrar uma "mudança de lado virtual" sem que você tivesse chegado perto da linha. Isso corromperia a detecção da próxima passagem real.

**Como resolvemos:** O app só atualiza o registro de "qual lado você está" quando o GPS está a menos de 20 metros da linha do setor. Longe demais = ignorado.

---

## Problema 3: uma curva com muitos pontos intermediários falhava na detecção

**O que acontecia:** Setores com geometria curva têm vários pontos no traçado. O algoritmo principal verifica a mudança de lado em cada mini-segmento da curva. Em algumas situações, o GPS "pulava" sobre o ponto sem gerar a mudança de lado esperada — e o cruzamento nunca era detectado.

**Como resolvemos:** Criamos um mecanismo de fallback: se o algoritmo principal não detectar o cruzamento, o app tenta de outra forma — mede a distância perpendicular do celular à linha e, se você passou de um lado para o outro e está perto o suficiente, registra o cruzamento mesmo assim.

---

## Problema 4: double-fire — o mesmo setor disparando duas vezes na mesma volta

**O que acontecia:** Perto da linha de setor, o GPS oscila para cá e para lá. Isso podia gerar dois cruzamentos detectados em sequência rapidíssima: você "cruzaria" o setor, o GPS oscilaria de volta, e cruzaria de novo — registrando dois setores onde havia só um.

**Como resolvemos:** Dois filtros em camadas:

1. **Cooldown de 10 segundos:** após detectar um cruzamento de setor, o app ignora qualquer novo cruzamento do mesmo setor pelos próximos 10 segundos. Tempo suficiente para sair da zona de oscilação.

2. **Tempo mínimo de 1 segundo:** se o tempo calculado para um setor for menor que 1 segundo, o app descarta esse registro. É fisicamente impossível completar um setor em menos de 1 segundo num kart.

---

## Resultado

Antes dessas correções, a taxa de detecção correta de setores estava entre 21% e 42% nos testes. Depois, chegou a mais de 90%.
