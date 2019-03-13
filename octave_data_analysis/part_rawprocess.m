% Poni�szy kod zosta� napisany dla programu Octave w wersji 4.2.1.
%
%	Autor: Lukasz Jozwiak
%
%	dzia�anie:
%
%			Program pobiera dane z pliku logu, dane s� surowymi odczytami z czujnika ci�nienia w czasie.
%			S� w postaci niewygodnej do dalszej obr�bki. Aby je wydajnie oblicza�, dane musza zosta�
%			Przekszta�cone do postaci tabeli.
%
%			Program wykonuje r�wnie� zaw�enie dziedziny tj. wybranie informacji istotnych (zakresu istotno�ci)
%			oraz zapisuje dane w wyj�ciowym pliku csv.
% ------------------------------------------------------------------------------

clear all;
close all;
clc;

lpath  = "/input/";         % �cie�ka dost�pu
lfname = "dep_input";       % nazwa pliku
lexten = ".log";            % rozszerzenie

t_pr = 294.25;              % temperatura ampu�y

spath  = "/output/";
sfadd  = "_result";
sexten = ".csv";

inputfile  = strcat(lpath, lfname, lexten);        % sk�adam �cie�k� do pl. wyj.
outputfile = strcat(spath, lfname, sfadd, sexten); % sk�adam �cie�k� do pl. wej.

print_1  = strcat(spath, lfname, "_indata.pdf" ); 
print_2  = strcat(spath, lfname, "_outdata.pdf");
raw_data = strcat(spath, lfname, "_raw", sexten); 

% wektory P i T wyznaczaj� ca�y zakres dost�pnych danych

[th, tm, ts, s, p] = textread(inputfile, '%d:%d:%f %d %f',
                              'delimiter', ',', 'HeaderLines', 3);

% Skopiowane warto�ci czasu znajduj� si� w trzech wektorach: godziny, minuty,
% sekundy. Zadaniem p�tli jest zwr�cenie do wektora T, sumy wszystkich trzech 
% wektor�w jako sumy element�w w sekundach.

T = double(th .* 3600) .+ double(tm .* 60) .+ double(ts);
P = p;

% otrzymany wektor T przechowuje warto�� bezwzgl�dn� w sekundach mierzonych od 
% poczatku doby nie jest to potrzebne i wektor czasu zostanie przeliczony 
% wzgl�dem warto�ci pocz�tkowej kt�ra b�dzie wynosi� 0.

T = T .- T(1,1);

T = T(1:end-3);
P = P(1:end-3);

% zwyczajowo czyszcz� wszystkie dane pomocnicze �eby zachowa� porz�dek 
% i przej�ysto�� kodu

clear i; clear p; clear s; clear t_i; clear th; clear tm; clear ts; clear lpath;
clear lfname; clear lexten; clear spath; clear sexten; clear inputfile;
clear sfadd;
% -----------------------------------------------------------------------------
% Stwierdzono podczas pisania kolejnych wersji kodu, �e dane pochodz�ce z sondy
% ci�nienia dla typu opisanego w rozprawie doktorskiej, zawieraj� szum kt�rego
% �r�d�o le�y w wielko�ci jednostki kwantyfikacji. Innymi s�owy czujnik nie jest
% do�� precyzyjny. Zastosowano wi�c funkcj� wyg�adzaj�c� kt�rej dzia�anie polega
% na konwolucji wektora P z wektorem jedynkowym o okre�lonej d�ugo�ci. Linia 
% tej konwolucji b�dzie wy�wietlana jako ma_P. Wypr�bowane warto�ci wektora
% jedynkowego zawieraj� si� w przedziale od 5 do 7.

wind = 7;               % Ustalam d�ugo�� wektora jedynkowego, u�ytkownik mo�e
                        % dokonywa� korekcji tej d�ugo�ci w oparciu o wykres.
mask = ones(1,wind)/wind;
ma_P = conv(P, mask, 'same'); % funkcja zwraca wektor o tej samej d�ugo�ci co
                              % wektor P lecz wind/2 skrajne punkty nie s� wa�ne
                              % z pewnych powod�w zosta�o to zaakceptowane.
                              
ma_P = round(ma_P .* 1000)./1000; % Zaokr�glenie do trzech miejsc po przecinku.

clear mask;  

% W dalszej cz�ci oblicze� dotycz�cych wyznaczenia przedzia�u istotno�ci danych
% zamiast wektorem P program b�dzie si� pos�ugiwa� wektorem ma_P.

% ------------------------------------------------------------------------------
% Wyznaczam punkt i_II kt�ry b�dzie odpowiada� maksymalnemu ci�nieniu 
% osi�gni�temu tu� po zap�onie mieszaniny w komorze. Jest to najwy�sze ci�nienie
% wyst�puj�ce podczas procesu.

p_II = max(ma_P);
i_II = find(ma_P == p_II);    % Funkcja znajduje wszystkie warto�� dla kt�rych 
                              % panuje warunek max(ma_P). Z winy du�ej jednostki
                              % kwantyfikacji w oryginalnym wektorze mo�e by�
                              % nawet kilka takich par. Program wyznaczy wtedy
                              % wirtualny �rodek.                        
                          
if(length(i_II) == 1)         % I je�li warto�� maksymalna nale�y do tylko 
                              % jednej pary to poszukiwanie punktu II si� ko�czy
  disp(" ---> found one i_II pair ")
  
  p_II = P(i_II,1);           % Zapisuj� p_II indeksuj�c wg. ma_P wektor P.
  t_II = T(i_II,1);           % Zapisuj� t_II indeksuj�c wg. ma_P wektor T.

endif

if(length(i_II) > 1)      % Je�li jednak warto�� maksymalna odpowiada wi�cej ni�
                          % jednej parze to nale�y zwi�kszy� warto�� "wind" i  
  disp(" ---> found more than one i_II pair, check <wind> parameter ")
  disp(" ---> ERROR ! , program aborted ")
  break                   % dalsze wykonywanie instrukcji jest pozbawione sensu.
                           
endif

% -----------------------------------------------------------------------------
% Dokonuj� oblicze� punkt i_I importowanej populacji, w tym celu posuwam si� od
% indeksu i_II do ty�u wektora ma_P rejestruj�c jeszcze nie zacz�ty wzrost 
% ci�nienia detekcja nast�puje je�li r�znica P(i) - P(i-1) jest mniejsza od
% warto�ci granicznej dif_p.

dif_p = 0.002;          % Ustalam minimaln� r�nic� pomi�dzy kolejnymi punktami.
i_p = i_II;
i_k = floor(wind/2);    % Pracuj�c z indeksami nale�y pami�ta� �e ich warto��
                        % musi pozosta� liczb� ca�kowit�.
                        
while(i_p>i_k)          % Wykonuj� dopuki indeks bie��cy jest wi�kszy od 
                        % indeksu ko�cowego.

  if(abs(ma_P(i_p,1) - ma_P((i_p-1),1)) > dif_p)
  i_p--;
  endif
  
  if(abs(ma_P(i_p,1) - ma_P((i_p-1),1)) <= dif_p)
  i_p--;                % o jednostk� w ty� by wybra� punkt przed skokiem
    i_I = i_p;
    i_p = 0;
  endif
  
endwhile

% Obliczony w ten spos�b indeks i_I jest przesuni�ty wzgl�dem wektora P o po�ow�
% wektora jedynkowego. Korzystaj�c z tego typu konwolucji nale�y pami�ta� o
% przesuni�ciach. Jedynie lokalne warto�ci min i max nie podlegaj� tej zasadzie.

i_I = i_I + floor(wind/2);
p_I = P(i_I,1);
t_I = T(i_I,1);

% ------------------------------------------------------------------------------
% Obliczam indeks punktu i_V co pozwala na �atwiejsz� obr�bk� serii danych 
% odcinaj�c zb�dne obszary ci�nie� le��cych poza w�a�ciwym procesem. Przyjmuj�
% �e warto�� dla punktu i_V jest identyczna jak dla punktu i_I. Algorytm jest
% s�uszny w je�li ci�nienie podczas procesu nie zbli�a si� zbytnio do p_I.

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
% Obliczam wsp�rz�dne punktu i_IV. Znaj�c dane punktu V u�ywam algorytmu 
% szukaj�cego kieruj�c si� od punktu i_V w stron� punktu i_II.

dif_p = 0.005;           % ustalam minimaln� r�nic� pomi�dzy kolejnymi punktami
i_p = i_V;

while(i_p>i_II)          % wykonuj dopuki indeks bie��cy wi�kszy od dw�ch

  if(abs(ma_P(i_p,1) - ma_P((i_p-1),1)) > dif_p)
  i_p--;
  endif
  
  if(abs(ma_P(i_p,1) - ma_P((i_p-1),1)) <= dif_p)
  i_p--;                  % o jednostk� w ty� by wybra� punkt przed skokiem
  i_IV = i_p;
  i_p = 0;
  endif
  
endwhile

i_IV = i_IV + floor(wind/2);

p_IV = P(i_IV,1);
t_IV = T(i_IV,1);

% ------------------------------------------------------------------------------
% Nast�puje koniec pierwszej cz�ci oblicze�. Przygotowuj� dane do wy�wietlenia
% w wykresie oraz "czyszcz�" zb�dne warto�ci pomocnicze.

% Wykres pierwszy, tj. dane wej�ciowe 

% Przygotowuj� wektor ma_P do wy�wietlenia.
ma_P_d = ma_P; ma_P_d([1:(i_I - floor(wind/2)), i_V:end]) = [];
T_d    =    T;    T_d([1:(i_I - floor(wind/2)), i_V:end]) = [];

% Generuj� wykres.
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
% Nast�puje druga cz�� oblicze� w kt�rych wyznaczony zostanie punkt i_III oraz
% powierzchnia A_III

% Tworz� wyj�ciowe wektory danych w oparciu o kt�re wykonam dalsze obliczenia
% i  wykres 2

L_limit = i_I;
R_limit = i_IV;

T_out = T; T_out([1:L_limit, R_limit:end]) = []; T_out = T_out .- T_out(1,1);
P_out = ma_P; P_out([1:L_limit, R_limit:end]) = []; P_out = P_out .- p_I;

% -----------------------------------------------------------------------------
% Obliczam ci�nienie parcjalne prekursora w czasach depozycji

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
% Poszukam punktu i_III wg nowej koncepcji tj. przesuwam si� od ko�ca do 
% pocz�tku wektora. Mog� zaj�� dwa przypadki:
% 1 - wyst�pi�a kondensacja, je�li tak to pojawi� si� w P_pr warto�ci mniejsze
%     od 0.
% 2 - nie wyst�pi�a kondensacja, je�li tak to niekt�re warto�ci w P_pr mog� by�
%     bardzo ma�e ale b�d� wi�ksze od 0
% We wszystkich przypadkach punkt i_III przyjmowa� b�dziemy jako punkt min(P_pr)
% lecz o warto�ci jeszcze wi�kszej b�d� r�wnej 0 oraz prawostronny.

i_p   = rows(P_pr);
p_min = min(P_pr);
i_k   = 1;

while(i_p>=i_k)

  if(P_pr(i_p,1) < 0)             % je�li bie��ca warto�� jest mniejsza od 0
    i_III = i_p + 1;              % czyli je�li zajdzie kondensacja
    break                         % to zwi�ksz indeks o 1 �eby nie doda� punktu
  endif                           % o ujemnym ci�nieniu i wyjd� z p�tli


  if(P_pr(i_p,1) == p_min);       % je�li bie��ca warto�� b�dzie r�wna min(P_pr)
    i_III = i_p;                  % to bie��cy indeks przepisz do i_III
    break                         % i wyjd� z p�tli (prawostronno��)
  endif

i_p--;
endwhile

p_III = P_out(i_III,1);      % Rzutuj� indeks i_III na wektory wyj�ciowe
t_III = T_out(i_III,1);

p_pr_III = P_pr(i_III,1);    % Rzutuj� indeks i_III na wektory parcjalne
t_pr_III = T_pr(i_III,1);

% ------------------------------------------------------------------------------
% Obliczenia dla stosunku ci�nie�
% Chc�c pozna� stosunek ci�nienia prekursora do ci�nienia w komorze
% Stosuj� spos�b polegaj�cy na stopniowym przybli�aniu si� do rozwi�zania.
% Przyjmuj� wi�c �e r�wnowaga ci�nieniowa (ze stabilizacj� ci�nienia) dominuje
% czasowo.

P_pr_diff = P_out ./ P_pr;      % Tworz� wektor stosunk�w ci�nie� (tj. rozk�adu)

p_diff_med = median(P_pr_diff); % znajduj� po raz pierwszy median� w wektorze 
                                % stosunk�w ci�nie�
i_p = rows(P_pr_diff);                
i_k = 1;

while(i_p>=i_k)                         % wyszukuj� indeks pocz�tkowy obszaru o
                                        % stosunkach mniejszych ni� mediana  
  if(P_pr_diff(i_p,1) > p_diff_med)
    i_p++;
    break
  endif

i_p--;
endwhile

p_diff_med = median(P_pr_diff(i_p:end,1)); % W zaw�onym wektorze wyznaczam
                                           % median� poraz drugi.

% powy�ej zasosowa�em p�tl� "od ko�ca do pocz�tku"
% druga p�tla b�dzie od pocz�tku do ko�ca

i_p;                    % nie zmieniamy indeksu pocz�tkowego
i_k = rows(P_pr_diff);  % indeks ko�cowy na koniec wektora

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
% Wyznaczam ca�k� z obszaru pomi�dzy punktem i_III oraz I_IV
% w tym celu musz� wyznaczy� wektor czas�w cz�stkowych dla tego obszaru.

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
A = sum(T_A_d .* P_A); % Obliczam powierzchni� podca�kow�

% ------------------------------------------------------------------------------
% Nast�puje koniec drugiej cz�ci oblicze�. Przygotowuj� dane do wy�wietlenia
% na wykresie oraz "czyszcz�" zb�dne warto�ci pomocnicze.

% Wykres drugi, tj. dane wygenerowane 

% Przygotowuj� wektor T_A kt�ry jest potrzebny tylko do wykresu.
T_A(1)   = [];

% Generuj� wykres.
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
% Generuj� raport
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% KONIEC OBLICZE�
% Nale�y jeszcze tylko wyeksportowa� obliczone parametry do pliku csv
% obiektem eksportu jest macie� o zawarto�ci mieszanej

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

% wstawiam puste znaki zamiast zer co u�atwi p�niejsz� prac� z plikiem np.
% w excelu

S(1, 6) = char("");
S(1, 7) = char("");

i_p = 5;  % od pi�tego rzedu kolumn 6 i 7
i_k = rows(S);

while(i_p<=i_k)

  S(i_p, 6) = char("");
  S(i_p, 7) = char("");

i_p++;
endwhile

cell2csv(outputfile, S, 'false', ',', 2011, '.');

% Analogicznie przygotowuj� plik rave_data

clear S;

S = zeros((rows(T)+1) ,2);

S(2:end,1) = T    (1:end,1);
S(2:end,2) = P    (1:end,1);

S = num2cell(S);

S(1,1) = "t [s]"     ; S(1,2) = "p [Pa]" ;

cell2csv(raw_data, S, 'false', ',', 2011, '.');

beep();