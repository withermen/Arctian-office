# Arctian Office

Arctian OS için beş ofis uygulaması: **Şafak** (metin), **Mürekkep** (çizim/not),
**Abaküs** (tablo/hesap), **Sahne** (sunum), **Mercek** (görsel/PDF görüntüleyici).

Bu repo uygulamaların kaynak kodunu, derleme betiğini ve indirilebilir `.wlf`
paketlerini bir arada tutar. Paketler GitHub Releases üzerinden yayınlanır:

- Katalog: `https://github.com/withermen/Arctian-office/releases/download/apps-v1/catalog.txt`
- Paketler: `.../apps-v1/<ad>.wlf` (`safak`, `murekkep`, `abakus`, `sahne`, `mercek`)

## Kurulum (Arctian OS içinde)

```sh
wf install safak        # katalogdan indirir ve kurar
wf install murekkep
wf install abakus
wf install sahne
wf install mercek
wf run safak            # kurduktan sonra çalıştır
```

Katalog adresi varsayılan olarak bu reponun `apps-v1` sürümünü gösterir.
Farklı bir katalog kullanmak için:

```sh
wf store <host> <port> <katalog-dosyasi>
```

Tek tek indirmek için terminalde:

```sh
curl https://github.com/withermen/Arctian-office/releases/download/apps-v1/safak.wlf
```

## Derleme

Gerekenler: `gcc`, `ld`, `objcopy`, `nm`, `readelf`, `python3` (WSL/Linux).

```sh
bash build.sh
```

Çıktı: `build/<ad>.wlf` + `build/catalog.txt` (imzasız).

Kurulabilir paket için imza anahtarı gerekir (Arctian imza doğrulaması zorunlu):

```sh
WOLF_KEY=/yol/dev_rsa2048.txt bash build.sh
```

`--inspect` ile paketi doğrulayabilirsiniz:

```sh
python3 sdk/wlfpack.py --inspect build/safak.wlf
```

## Yükleme adresi (önemli)

Bir `.wlf` paketi yalnızca **yükleme tabanı (WLF_BASE) kendisini üreten imajla
aynı** olan Arctian sürümlerinde çalışır. Yanlış adresle derlenen paket
`wf install` sırasında "geçerli .wlf değil" diye reddedilir (doğrulama kodu `-10`).

| İmaj | WLF_BASE | Derleme |
| --- | --- | --- |
| `arctian08.iso` (0.9 ilk ISO) | `0x03000000` | varsayılan |
| 13 Kasım sonrası bellek haritası | `0x06800000` | `WOLF_LOAD=0x06800000 bash build.sh` |

Yani herhangi bir sürüm için:

```sh
WOLF_LOAD=0x06800000 bash build.sh
```

Release'e yüklenen paketler `0x03000000` tabanıyla derlenmiştir (0.9 ilk ISO).

## Uygulama izinleri

Her uygulama `wolf.json` içinde izinlerini bildirir (`fs`, `exec`). Uygulamalar
çekirdek/LVGL sembolü kullanmaz; yalnızca `libWolf` API'si (`sdk/include/wolf.h`)
üzerinden çalışır.

## Lisans

CC BY 4.0 — bkz. [LICENSE](LICENSE).
