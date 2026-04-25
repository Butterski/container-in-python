# Piszemy Dockera w 100 linijkach Pythona

Projekt stworzony na **20. Sesję Linuksową we Wrocławiu**.

**Autor:** Miłosz Kucharski

Projekt jest inspirowany i oparty na słynnej prelekcji *"Containers from Scratch"*, która oryginalnie przedstawiała implementację w języku Go (autorstwa Liz Rice). Ta repozytorium to adaptacja przedstawionych w niej koncepcji, ilustrująca jak zbudować własny silnik kontenerów (podobny do Dockera) używając zaledwie ~100 linijek kodu w języku Python.

## O co w tym chodzi?
Stworzony `container.py` demonstruje, z czego tak naprawdę pod maską składają się kontenery. Wykorzystujemy do tego natywne, niskopoziomowe mechanizmy systemu Linux:
- **Namespaces (Przestrzenie nazw):** Izolacja na poziomie procesów (PID), punktów montowania (Mount), nazw hosta (UTS) oraz interfejsów sieciowych (Net).
- **Chroot:** Izolacja systemu plików i zmiana jego katalogu głównego na podany `rootfs` (Root Filesystem).
- **Cgroups v2:** Kontrola i limitowanie zasobów sprzętowych (CPU, RAM).

## Wymagania
- System Linux (skrypt korzysta z mechanizmów ściśle linuksowych m.in. Cgroups v2)
- Uprawnienia administratora (`root` / `sudo`) niezbędne do modyfikacji przestrzeni nazw w systemie.
- Python 3
- Przygotowany rootfs (np. wypakowany system plików środowiska bazowego takiego jak Alpine lub Ubuntu). W repozytorium dołączony jest np. skrypt posiłkowy `download_alpine.sh`.

## Użycie 

Uruchomienie kontenera domyślnym procesem (np. powłoką `/bin/sh`):
```bash
sudo python3 container.py run --rootfs ./alpine_rootfs /bin/sh
```

Uruchomienie kontenera z nałożonymi limitami zasobów (np. 50MB RAM i obcięty CPU):
```bash
sudo python3 container.py run --rootfs ./alpine_rootfs --memory 50 --cpu 20 /bin/sh
```
