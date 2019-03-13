% Poni¿szy kod zosta³ napisany dla programu Octave w wersji 4.2.1.
%
%	Autor: Lukasz Jozwiak
%
%	dzia³anie:
%
%			Program pobiera dane z pliku logu, dane s¹ surowymi odczytami z czujnika ciœnienia w czasie.
%			S¹ w postaci niewygodnej do dalszej obróbki. Aby je wydajnie obliczaæ, dane musza zostaæ
%			Przekszta³cone do postaci tabeli.
%
%			Program wykonuje równie¿ zawê¿enie dziedziny tj. wybranie informacji istotnych (zakresu istotnoœci)
%			oraz zapisuje dane w wyjœciowym pliku csv.
% ------------------------------------------------------------------------------

clear all;
close all;
clc;

lpath  = "/input/";         % œcie¿ka dostêpu
lfname = "dep_input";       % nazwa pliku
lexten = ".log";            % rozszerzenie

t_pr = 294.25;              % temperatura ampu³y

spath  = "/output/";
sfadd  = "_result";
sexten = ".csv";

inputfile  = strcat(lpath, lfname, lexten);        % sk³adam œcie¿kê do pl. wyj.
outputfile = strcat(spath, lfname, sfadd, sexten); % sk³adam œcie¿kê do pl. wej.

print_1  = strcat(spath, lfname, "_indata.pdf" ); 
print_2  = strcat(spath, lfname, "_outdata.pdf");
raw_data = strcat(spath, lfname, "_raw", sexten); 

% wektory P i T wyznaczaj¹ ca³y zakres dostêpnych danych

[th, tm, ts, s, p] = textread(inputfile, '%d:%d:%f %d %f',
                              'delimiter', ',', 'HeaderLines', 3);

% Skopiowane wartoœci czasu znajduj¹ siê w trzech wektorach: godziny, minuty,
% sekundy. Zadaniem pêtli jest zwrócenie do wektora T, sumy wszystkich trzech 
% wektorów jako sumy elementów w sekundach.

T = double(th .* 3600) .+ double(tm .* 60) .+ double(ts);
P = p;

% otrzymany wektor T przechowuje wartoœæ bezwzglêdn¹ w sekundach mierzonych od 
% poczatku doby nie jest to potrzebne i wektor czasu zostanie przeliczony 
% wzglêdem wartoœci pocz¹tkowej która bêdzie wynosiæ 0.

T = T .- T(1,1);

T = T(1:end-3);
P = P(1:end-3);

% zwyczajowo czyszczê wszystkie dane pomocnicze ¿eby zachowaæ porz¹dek 
% i przej¿ystoœæ kodu

clear i; clear p; clear s; clear t_i; clear th; clear tm; clear ts; clear lpath;
clear lfname; clear lexten; clear spath; clear sexten; clear inputfile;
clear sfadd;
% -----------------------------------------------------------------------------
% Stwierdzono podczas pisania kolejnych wersji kodu, ¿e dane pochodz¹ce z sondy
% ciœnienia dla typu opisanego w rozprawie doktorskiej, zawieraj¹ szum którego
% Ÿród³o le¿y w wielkoœci jednostki kwantyfikacji. Innymi s³owy czujnik nie jest
% doœæ precyzyjny. Zastosowano wiêc funkcjê wyg³adzaj¹c¹ której dzia³anie polega
% na konwolucji wektora P z wektorem jedynkowym o okreœlonej d³ugoœci. Linia 
% tej konwolucji bêdzie wyœwietlana jako ma_P. Wypróbowane wartoœci wektora
% jedynkowego zawieraj¹ siê w przedziale od 5 do 7.

wind = 7;               % Ustalam d³ugoœæ wektora jedynkowego, u¿ytkownik mo¿e
                        % dokonywaæ korekcji tej d³ugoœci w oparciu o wykres.
mask = ones(1,wind)/wind;
ma_P = conv(P, mask, 'same'); % funkcja zwraca wektor o tej samej d³ugoœci co
                              % wektor P lecz wind/2 skrajne punkty nie s¹ wa¿ne
                              % z pewnych powodów zosta³o to zaakceptowane.
                              
ma_P = round(ma_P .* 1000)./1000; % Zaokr¹glenie do trzech miejsc po przecinku.

clear mask;  

% W dalszej czêœci obliczeñ dotycz¹cych wyznaczenia przedzia³u istotnoœci danych
% zamiast wektorem P program bêdzie siê pos³ugiwa³ wektorem ma_P.

% ------------------------------------------------------------------------------
% Wyznaczam punkt i_II który bêdzie odpowiada³ maksymalnemu ciœnieniu 
% osi¹gniêtemu tu¿ po zap³onie mieszaniny w komorze. Jest to najwy¿sze ciœnienie
% wystêpuj¹ce podczas procesu.

p_II = max(ma_P);
i_II = find(ma_P == p_II);    % Funkcja znajduje wszystkie wartoœæ dla których 
                              % panuje warunek max(ma_P). Z winy du¿ej jednostki
                              % kwantyfikacji w oryginalnym wektorze mo¿e byæ
                              % nawet kilka takich par. Program wyznaczy wtedy
                              % wirtualny œrodek.                        
                          
if(length(i_II) == 1)         % I jeœli wartoœæ maksymalna nale¿y do tylko 
                              % jednej pary to poszukiwanie punktu II siê koñczy
  disp(" ---> found one i_II pair ")
  
  p_II = P(i_II,1);           % Zapisujê p_II indeksuj¹c wg. ma_P wektor P.
  t_II = T(i_II,1);           % Zapisujê t_II indeksuj¹c wg. ma_P wektor T.

endif

if(length(i_II) > 1)      % Jeœli jednak wartoœæ maksymalna odpowiada wiêcej ni¿
                          % jednej parze to nale¿y zwiêkszyæ wartoœæ "wind" i  
  disp(" ---> found more than one i_II pair, check <wind> parameter ")
  disp(" ---> ERROR ! , program aborted ")
  break                   % dalsze wykonywanie instrukcji jest pozbawione sensu.
                           
endif

% -----------------------------------------------------------------------------
% Dokonujê obliczeñ punkt i_I importowanej populacji, w tym celu posuwam siê od
% indeksu i_II do ty³u wektora ma_P rejestruj¹c jeszcze nie zaczêty wzrost 
% ciœnienia detekcja nastêpuje jeœli róznica P(i) - P(i-1) jest mniejsza od
% wartoœci granicznej dif_p.

dif_p = 0.002;          % Ustalam minimaln¹ ró¿nicê pomiêdzy kolejnymi punktami.
i_p = i_II;
i_k = floor(wind/2);    % Pracuj¹c z indeksami nale¿y pamiêtaæ ¿e ich wartoœæ
                        % musi pozostaæ liczb¹ ca³kowit¹.
                        
while(i_p>i_k)          % Wykonujê dopuki indeks bie¿¹cy jest wiêkszy od 
                        % indeksu koñcowego.

  if(abs(ma_P(i_p,1) - ma_P((i_p-1),1)) > dif_p)
  i_p--;
  endif
  
  if(abs(ma_P(i_p,1) - ma_P((i_p-1),1)) <= dif_p)
  i_p--;                % o jednostkê w ty³ by wybraæ punkt przed skokiem
    i_I = i_p;
    i_p = 0;
  endif
  
endwhile

% Obliczony w ten sposób indeks i_I jest przesuniêty wzglêdem wektora P o po³owê
% wektora jedynkowego. Korzystaj¹c z tego typu konwolucji nale¿y pamiêtaæ o
% przesuniêciach. Jedynie lokalne wartoœci min i max nie podlegaj¹ tej zasadzie.

i_I = i_I + floor(wind/2);
p_I = P(i_I,1);
t_I = T(i_I,1);

% ------------------------------------------------------------------------------
% Obliczam indeks punktu i_V co pozwala na ³atwiejsz¹ obróbkê serii danych 
% odcinaj¹c zbêdne obszary ciœnieñ le¿¹cych poza w³aœciwym procesem. Przyjmujê
% ¿e wartoœæ dla punktu i_V jest identyczna jak dla punktu i_I. Algorytm jest
% s³uszny w jeœli ciœnienie podczas procesu nie zbli¿a siê zbytnio do p_I.

i_p = i_II;

while(i_p>=i_II)

  if(P(i_p,1) > p_I)
    i_p++;
  endif
  
  if(P(i_p,1) <= p_I)
    i_p--;
    i_V = i_p;
    i_p = 0;
  endif
  
endwhile

p_V = P(i_V,1);
t_V = T(i_V,1);

% ------------------------------------------------------------------------------
% Obliczam wspó³rzêdne punktu i_IV. Znaj¹c dane punktu V u¿ywam algorytmu 
% szukaj¹cego kieruj¹c siê od punktu i_V w stronê punktu i_II.

dif_p = 0.005;           % ustalam minimaln¹ ró¿nicê pomiêdzy kolejnymi punktami
i_p = i_V;

while(i_p>i_II)          % wykonuj dopuki indeks bie¿¹cy wiêkszy od dwóch

  if(abs(ma_P(i_p,1) - ma_P((i_p-1),1)) > dif_p)
  i_p--;
  endif
  
  if(abs(ma_P(i_p,1) - ma_P((i_p-1),1)) <= dif_p)
  i_p--;                  % o jednostkê w ty³ by wybraæ punkt przed skokiem
  i_IV = i_p;
  i_p = 0;
  endif
  
endwhile

i_IV = i_IV + floor(wind/2);

p_IV = P(i_IV,1);
t_IV = T(i_IV,1);

% ------------------------------------------------------------------------------
% Nastêpuje koniec pierwszej czêœci obliczeñ. Przygotowujê dane do wyœwietlenia
% w wykresie oraz "czyszczê" zbêdne wartoœci pomocnicze.

% Wykres pierwszy, tj. dane wejœciowe 

% Przygotowujê wektor ma_P do wyœwietlenia.
ma_P_d = ma_P; ma_P_d([1:(i_I - floor(wind/2)), i_V:end]) = [];
T_d    =    T;    T_d([1:(i_I - floor(wind/2)), i_V:end]) = [];

% Generujê wykres.
figure(1,"position",get(0,"screensize")([3,4,3,4]).*[0.03 0.45 0.45 0.45]) 
hold on;

plot(T,P,        '.' )
plot(T_d,ma_P_d, 'm' )
plot(t_II, p_II, 'ob')
plot(t_I,   p_I, 'or')
plot(t_V,   p_V, 'or')
plot(t_IV,  p_IV,'ob')

legend ("original data points            ", 
                                ["convolution, ones length = " int2str(wind)]);

text ((t_II + 0.07), (p_II + 0.03), "II")
text ((t_I  + 0.07), (p_I  + 0.03), "I" )
text ((t_V  + 0.07), (p_V  + 0.03), "V" )
text ((t_IV + 0.07), (p_IV + 0.03), "IV")

title ("p vs t , Input Data")
xlabel ("time t[s]")
ylabel ("pressure p[Pa]")

clear ans; clear dif_p; clear x1_hi; clear x1_lo, clear y1_hi, clear y1_lo;

% ------------------------------------------------------------------------------
% Nastêpuje druga czêœæ obliczeñ w których wyznaczony zostanie punkt i_III oraz
% powierzchnia A_III

% Tworzê wyjœciowe wektory danych w oparciu o które wykonam dalsze obliczenia
% i  wykres 2

L_limit = i_I;
R_limit = i_IV;

T_out = T; T_out([1:L_limit, R_limit:end]) = []; T_out = T_out .- T_out(1,1);
P_out = ma_P; P_out([1:L_limit, R_limit:end]) = []; P_out = P_out .- p_I;

% -----------------------------------------------------------------------------
% Obliczam ciœnienie parcjalne prekursora w czasach depozycji

i_p = 1;
i_k = rows(P);
P_pr = zeros(i_k,1);

while(i_p<=i_k)

  P_pr(i_p,1) = get_prp(ma_P(i_p,1) , t_pr);
  
i_p++;
endwhile

T_pr = T; T_pr([1:L_limit, R_limit:end]) = []; T_pr = T_pr .- T_pr(1,1);
P_pr([1:L_limit, R_limit:end]) = [];

clear L_limit; clear R_limit;

% -----------------------------------------------------------------------------
% Poszukam punktu i_III wg nowej koncepcji tj. przesuwam siê od koñca do 
% pocz¹tku wektora. Mog¹ zajœæ dwa przypadki:
% 1 - wyst¹pi³a kondensacja, jeœli tak to pojawi¹ siê w P_pr wartoœci mniejsze
%     od 0.
% 2 - nie wyst¹pi³a kondensacja, jeœli tak to niektóre wartoœci w P_pr mog¹ byæ
%     bardzo ma³e ale bêd¹ wiêksze od 0
% We wszystkich przypadkach punkt i_III przyjmowaæ bêdziemy jako punkt min(P_pr)
% lecz o wartoœci jeszcze wiêkszej b¹d¿ równej 0 oraz prawostronny.

i_p   = rows(P_pr);
p_min = min(P_pr);
i_k   = 1;

while(i_p>=i_k)

  if(P_pr(i_p,1) < 0)             % jeœli bie¿¹ca wartoœæ jest mniejsza od 0
    i_III = i_p + 1;              % czyli jeœli zajdzie kondensacja
    break                         % to zwiêksz indeks o 1 ¿eby nie dodaæ punktu
  endif                           % o ujemnym ciœnieniu i wyjdŸ z pêtli


  if(P_pr(i_p,1) == p_min);       % jeœli bie¿¹ca wartoœæ bêdzie równa min(P_pr)
    i_III = i_p;                  % to bie¿¹cy indeks przepisz do i_III
    break                         % i wyjd¿ z pêtli (prawostronnoœæ)
  endif

i_p--;
endwhile

p_III = P_out(i_III,1);      % Rzutujê indeks i_III na wektory wyjœciowe
t_III = T_out(i_III,1);

p_pr_III = P_pr(i_III,1);    % Rzutujê indeks i_III na wektory parcjalne
t_pr_III = T_pr(i_III,1);

% ------------------------------------------------------------------------------
% Obliczenia dla stosunku ciœnieñ
% Chc¹c poznaæ stosunek ciœnienia prekursora do ciœnienia w komorze
% Stosujê sposób polegaj¹cy na stopniowym przybli¿aniu siê do rozwi¹zania.
% Przyjmujê wiêc ¿e równowaga ciœnieniowa (ze stabilizacj¹ ciœnienia) dominuje
% czasowo.

P_pr_diff = P_out ./ P_pr;      % Tworzê wektor stosunków ciœnieñ (tj. rozk³adu)

p_diff_med = median(P_pr_diff); % znajdujê po raz pierwszy medianê w wektorze 
                                % stosunków ciœnieñ
i_p = rows(P_pr_diff);                
i_k = 1;

while(i_p>=i_k)                         % wyszukujê indeks pocz¹tkowy obszaru o
                                        % stosunkach mniejszych ni¿ mediana  
  if(P_pr_diff(i_p,1) > p_diff_med)
    i_p++;
    break
  endif

i_p--;
endwhile

p_diff_med = median(P_pr_diff(i_p:end,1)); % W zawê¿onym wektorze wyznaczam
                                           % medianê poraz drugi.

% powy¿ej zasosowa³em pêtlê "od koñca do pocz¹tku"
% druga pêtla bêdzie od pocz¹tku do koñca

i_p;                    % nie zmieniamy indeksu pocz¹tkowego
i_k = rows(P_pr_diff);  % indeks koñcowy na koniec wektora

while(i_p<=i_k)

  if(P_pr_diff(i_p,1)<= p_diff_med)
    break
  endif

i_p++;
endwhile

i_diff   = i_p;
p_eq_pr  = P_pr(i_diff,1);
t_eq_pr  = T_pr(i_diff,1);

p_eq_out = P_out(i_diff,1);
t_eq_out = T_out(i_diff,1);

ratio = mean(P_pr_diff(i_diff:end, 1));

% -----------------------------------------------------------------------------
% Wyznaczam ca³kê z obszaru pomiêdzy punktem i_III oraz I_IV
% w tym celu muszê wyznaczyæ wektor czasów cz¹stkowych dla tego obszaru.

T_A = T_pr((i_III-1):end,1);
P_A = P_pr(i_III:end,1);

i_p = 2;
i_k = rows(T_A);

T_A_d = T_A;

while(i_p<=i_k)

  T_A_d(i_p,1) = T_A(i_p,1) - T_A((i_p-1),1); 

i_p++;
endwhile

T_A_d(1) = [];
A = sum(T_A_d .* P_A); % Obliczam powierzchniê podca³kow¹

% ------------------------------------------------------------------------------
% Nastêpuje koniec drugiej czêœci obliczeñ. Przygotowujê dane do wyœwietlenia
% na wykresie oraz "czyszczê" zbêdne wartoœci pomocnicze.

% Wykres drugi, tj. dane wygenerowane 

% Przygotowujê wektor T_A który jest potrzebny tylko do wykresu.
T_A(1)   = [];

% Generujê wykres.
figure(2,"position",get(0,"screensize")([3,4,3,4]).*[0.52 0.45 0.45 0.45])  
hold on;

plot(T_out,P_out,       'b')
plot(T_pr,P_pr,         'r')

area(T_A,P_A)

plot(t_III,p_III,       'or')
plot(t_pr_III,p_pr_III, 'ob')

plot(t_eq_pr,p_eq_pr,   '.r')
plot(t_eq_out,p_eq_out, 'xr')

text((t_eq_pr + 0.07),  (p_eq_pr + 0.03), 
                                      ["Integral = " num2str(A)]) 
text((t_eq_out + 0.07), (p_eq_out + 0.03), 
                                      ["Equilibrium, ratio = " num2str(ratio)])
text((t_III + 0.07), (p_III + 0.03), "III")

legend("Overall presure", "Precursor pressure");

title ("p vs. t , Output Data");
xlabel("time t, [s]");
ylabel("pressure p, [Pa]");

%saveas(1, "figure1.png");

clear ans; clear i_p; clear i_k;

saveas(1, print_1);
saveas(2, print_2);

I = zeros(rows(T_out), 1);

i_p = 1;
i_k = rows(T_out);

while(i_p <= i_k)

  I(i_p,1) = i_p;

i_p++;
endwhile

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Generujê raport
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% KONIEC OBLICZEÑ
% Nale¿y jeszcze tylko wyeksportowaæ obliczone parametry do pliku csv
% obiektem eksportu jest macie¿ o zawartoœci mieszanej

% ind, T_out [s], P_out [Pa], T_pr [s], P_pr [Pa], 
%   1,       val,        val,      val,       val, Integral A_III, val,
%   2,       val,        val,      val,       val,     Ratio P/Pr, val,
%   3,       val,        val,      val,       val,    (i)ndex_III, val,

S = zeros((rows(T_out)+1) ,7);

S(2:end,1) = I    (1:end,1);
S(2:end,2) = T_out(1:end,1);
S(2:end,3) = P_out(1:end,1);
S(2:end,4) = T_pr (1:end,1);
S(2:end,5) = P_pr (1:end,1);

S(2,7) = A;
S(3,7) = ratio;
S(4,7) = i_III;

S = num2cell(S);

S(1,1) = "Ind"     ; S(1,2) = "T_out [s]" ; S(1,3) = "P_out[Pa]" ;
S(1,4) = "T_pr [s]"; S(1,5) = "P_pr [Pa]" ;

S(2,6) = "Integral A_III"  ; S(3,6) = "Ratio P/Pr"  ; S(4,6) = "(i)ndex_III" ;

% wstawiam puste znaki zamiast zer co u³atwi póŸniejsz¹ pracê z plikiem np.
% w excelu

S(1, 6) = char("");
S(1, 7) = char("");

i_p = 5;  % od pi¹tego rzedu kolumn 6 i 7
i_k = rows(S);

while(i_p<=i_k)

  S(i_p, 6) = char("");
  S(i_p, 7) = char("");

i_p++;
endwhile

cell2csv(outputfile, S, 'false', ',', 2011, '.');

% Analogicznie przygotowujê plik rave_data

clear S;

S = zeros((rows(T)+1) ,2);

S(2:end,1) = T    (1:end,1);
S(2:end,2) = P    (1:end,1);

S = num2cell(S);

S(1,1) = "t [s]"     ; S(1,2) = "p [Pa]" ;

cell2csv(raw_data, S, 'false', ',', 2011, '.');

beep();