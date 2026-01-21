# CO ZOSTAŁO ZREALIZOWANE?

- generowanie mapy z przszkodami
- gracz w postaci trójkąta z okrągłym colliderem
 - sterowny klawiatują (WSAD) oraz myszką (W - ruch do kursoramyszy)
 - posiada status zdrowia (pasek w lewym górnym rogu) oraz koniec gry, czy zdrowie = 0

- przeciwnicy - okręgi z colliderami mogące być w 2 trybach: ucieczki lub walki
 - w trybie ucieczki - kolor niebieski - przeciwnicy chowają się za przeszkodami (hide from player)
   i losowo wędrują w ukryciu omijając przeszkody i siebie nazwajem (obstacle avoidance)
   oraz krawędzie mapy (wall avoidance) delikatnie wędrująć (wander)
 - od czasu do czasu przeciwnikowi losowo zostaje zwiększona odwaga (bravery level) - kolor biały
   wtedy wędrują bardziej swobodnie (wander) po mapie nie przejmując się graczem
 - gdy w danym obszarze zgromadzi się odpowiednio dużo przeciwników przechodzi do trybu ataku
   (im więcej przeciwnik ma "sąsiadów" tym bardziej czerwona staje się jego oko (węwnętrzna kropa)
 - w trybie ataku przeciwnicy przejawiąją zachowania stadne (flocking behaviours:
   separation, cohesion, alignment) oraz podążają za graczem
 - w trybie ataku dotyk przeciwników odbiera garzczowi jeden punkt życia na jednostkę czasu

- implementacja ruchów jest wzorowana na treści książki z kilkoma włanymi rozwiązaniami, szczególnie:
  - arrive slalom - próba bardzij efektywnego omijania przeszkód przez wyznaczanie pośredniego punku nawigacyjnego
  - hide from player - jeśli przeciwnik znajduje się po przeciwnej stronie przeszkody względem punku schronienia
    będzie się starał ominąć przeszkodę po stronie bardzij zgodnej z jego obecnym kierunkiem ruchu

- nadal pozostają pewne sytuacje, gdy siły ruchu o przeciwnych zwrotach zatrzymują przeciwników w miejscu
  szczególnie w okolicy przeszkód - jest to pole do dalszych poprawek
