--=============================================================================
-- BadWords.lua -- penyaring kata kotor ID + EN
--=============================================================================
-- Modul mandiri: tidak bergantung pada apa pun, bisa dipakai di Roblox, di
-- loader, atau diterjemahkan ke PHP dengan menyalin tabelnya saja.
--
-- TIGA hal yang membuat daftar mentah selalu jebol, dan ketiganya ditangani
-- di sini:
--
--   1. PENYAMARAN KARAKTER.  "4nj1ng", "@sU", "b4b1", "5hit"
--   2. PEMISAH DI TENGAH.    "a n j i n g", "a.n.j.i.n.g", "a-n-j-i-n-g"
--   3. HURUF DIULANG.        "anjiiiing", "goblooook", "fuuuck"
--
-- Dan satu hal yang membuat daftar mentah SALAH TANGKAP -- ini yang paling
-- sering bikin pemakai tidak bersalah kena ban:
--
--   "asu"   ada di kasur, asuransi, mengasuh, asupan, basuh
--   "tai"   ada di pantai, sampai, detail, petai, Taiwan
--   "coli"  ada di brokoli, colic, Colin
--   "memek" ada di memekik
--   "babi"  ada di babirusa
--   "ass"   ada di class, pass, assist, embassy, assassin
--   "hell"  ada di hello, shell, Michelle
--   "cock"  ada di cockpit, peacock, cocktail
--   "anal"  ada di analysis, analyst, canal
--
-- Karena itu daftarnya DIPISAH DUA:
--   KATA_UTUH  -- hanya cocok kalau berdiri sendiri sebagai kata
--   POTONGAN   -- boleh cocok di tengah kata (khusus yang panjang & khas)
--
-- Salah menaruh satu kata di POTONGAN padahal seharusnya KATA_UTUH = laporan
-- "chat gw kena filter padahal gw ngetik kasur". Kalau ragu, taruh di
-- KATA_UTUH.
--=============================================================================

local Kotor = {}

--=============================================================================
-- TINGKAT
--=============================================================================
-- 3 = berat   : seksual eksplisit, hinaan identitas (ras/agama/orientasi)
-- 2 = sedang  : umpatan kasar
-- 1 = ringan  : hinaan ringan, sering dipakai bercanda
--
-- Dipisah supaya pemilik server bisa memilih ketegasannya sendiri. Chat game
-- anak-anak menyaring dari 1; chat komunitas dewasa biasanya dari 2 atau 3.
Kotor.BERAT, Kotor.SEDANG, Kotor.RINGAN = 3, 2, 1

--=============================================================================
-- INDONESIA -- KATA UTUH
--=============================================================================
local ID_UTUH = {
    -- berat: seksual
    ["kontol"]=3, ["kntl"]=3, ["kntol"]=3, ["memek"]=3, ["mmk"]=3, ["mek"]=3,
    ["pepek"]=3, ["pepe"]=3, ["puki"]=3, ["pukimak"]=3, ["pukima"]=3,
    ["kimak"]=3, ["kimk"]=3, ["ngentot"]=3, ["ngentod"]=3, ["ngentotin"]=3,
    ["ngtt"]=3, ["ngewe"]=3, ["ewe"]=3, ["coli"]=3, ["colmek"]=3, ["onani"]=3,
    ["peler"]=3, ["plr"]=3, ["titit"]=3, ["kotek"]=3, ["itil"]=3,
    ["jembut"]=3, ["jmbt"]=3, ["jembud"]=3, ["toket"]=3, ["tetek"]=3,
    ["nenen"]=3,
    ["kontl"]=3, ["kntt"]=3, ["ngaceng"]=3, ["ereksi"]=3, ["crot"]=3,
    ["croot"]=3, ["sange"]=3, ["sangean"]=3, ["horni"]=3, ["birahi"]=3,
    ["pelacur"]=3, ["lonte"]=3, ["lont"]=3, ["sundal"]=3, ["jablay"]=3,
    ["bispak"]=3, ["gigolo"]=3, ["germo"]=3, ["mucikari"]=3, ["wts"]=3,
    ["bokep"]=3, ["bokeb"]=3, ["mesum"]=3, ["cabul"]=3, ["perek"]=3, 

    -- berat: hinaan identitas
    ["bencong"]=3, ["banci"]=3, ["bences"]=3, ["homo"]=3, ["hombreng"]=3,
    ["lesbong"]=3, ["kafir"]=3, ["cina"]=3, ["cokin"]=3, ["nigger"]=3,
    ["negro"]=3, ["yahudi"]=3, ["pki"]=3, ["sipit"]=3, ["kunyuk"]=3,

    -- sedang: umpatan kasar
    ["anjing"]=2, ["anjg"]=2, ["anjeng"]=2, ["anjink"]=2, ["anjir"]=1,
    ["anjay"]=1, ["anj"]=2, ["njing"]=2, ["njir"]=1, ["ajg"]=2,
    ["bangsat"]=2, ["bangsad"]=2, ["bgst"]=2, ["bgsd"]=2, ["bngst"]=2,
    ["bajingan"]=2, ["bajindul"]=2, ["bjir"]=1, ["bjg"]=2,
    ["jancok"]=2, ["jancuk"]=2, ["jancuq"]=2, ["cok"]=2, ["cuk"]=2,
    ["jncok"]=2, ["jnck"]=2, ["dancok"]=2, ["diancuk"]=2, ["cukimai"]=3,
    ["asu"]=2, ["asw"]=2, ["asyu"]=2,
    ["babi"]=2, ["bab1"]=2, ["bagong"]=2, ["celeng"]=2,
    ["keparat"]=2, ["kprt"]=2, ["brengsek"]=2, ["bangke"]=2, ["bangkai"]=2,
    ["laknat"]=2, ["biadab"]=2, ["bedebah"]=2, ["sialan"]=2, ["sial"]=1,
    ["setan"]=2, ["syaitan"]=2, ["iblis"]=2, ["dajjal"]=2,
    ["tai"]=2, ["taik"]=2, ["tahi"]=2, ["tay"]=1, ["taeq"]=2,
    ["kampret"]=2, ["kampang"]=2, ["kamvret"]=1, ["kimpet"]=2,
    ["monyet"]=2, ["monyong"]=2, ["mnyt"]=2, ["lutung"]=2,
    ["bacot"]=2, ["bct"]=2, ["bacod"]=2, ["cangkem"]=2, ["cocot"]=2,
    ["ngaco"]=1, ["sompret"]=1, ["sompral"]=2, ["kunyuk"]=2,
    ["pantek"]=2, ["pantat"]=2, ["silit"]=2, ["burit"]=2,

    -- ringan: hinaan ringan
    ["tolol"]=1, ["tll"]=1, ["toll"]=1, ["goblok"]=1, ["gblk"]=1,
    ["goblog"]=1, ["bego"]=1, ["bgo"]=1, ["bodoh"]=1, ["dungu"]=1,
    ["oon"]=1, ["ooon"]=1, ["idiot"]=1, ["sinting"]=1, ["gila"]=1,
    ["gendeng"]=1, ["edan"]=1, ["stress"]=1, ["autis"]=1, ["cacat"]=1,
    ["jelek"]=1, ["norak"]=1, ["kampungan"]=1, ["udik"]=1, ["ndeso"]=1,
    ["miskin"]=1, ["gembel"]=1, ["sampah"]=1, ["kacung"]=1, ["babu"]=1,
    ["jongos"]=1, ["culun"]=1, ["cupu"]=1, ["lemot"]=1, ["katrok"]=1, ["bug"]=1,
}

--=============================================================================
-- INDONESIA -- POTONGAN (boleh di tengah kata)
--=============================================================================
-- Hanya yang PANJANG dan KHAS. Di bawah 6 huruf hampir selalu salah tangkap,
-- jadi jangan ditambah ke sini tanpa diuji dulu ke kamus.
local ID_POTONG = {
    ["ngentot"]=3, ["ngentod"]=3, ["pukimak"]=3, ["cukimai"]=3,
    ["bangsat"]=2, ["bajingan"]=2, ["keparat"]=2, ["brengsek"]=2,
    ["jancok"]=2, ["jancuk"]=2, ["kampret"]=2, ["pelacur"]=3,
    ["bencong"]=3, ["mucikari"]=3, ["kontol"]=3, ["memek"]=3,
    ["goblok"]=1, ["jembut"]=3, ["colmek"]=3, ["bispak"]=3,
}

--=============================================================================
-- INGGRIS -- KATA UTUH
--=============================================================================
local EN_UTUH = {
    -- berat: seksual
    ["cock"]=3, ["cocks"]=3, ["dick"]=3, ["dicks"]=3, ["dik"]=3,
    ["penis"]=3, ["pussy"]=3, ["pussies"]=3, ["puss"]=3, ["cunt"]=3,
    ["cunts"]=3, ["twat"]=3, ["vagina"]=3, ["vag"]=3, ["clit"]=3,
    ["boob"]=3, ["boobs"]=3, ["tits"]=3, ["titties"]=3, ["titty"]=3,
    ["nipple"]=3, ["nipples"]=3, ["anus"]=3, ["anal"]=3, ["rectum"]=3,
    ["cum"]=3, ["cumming"]=3, ["jizz"]=3, ["semen"]=3, ["sperm"]=3,
    ["wank"]=3, ["wanker"]=3, ["jerkoff"]=3, ["handjob"]=3, ["blowjob"]=3,
    ["bj"]=3, ["rimjob"]=3, ["deepthroat"]=3, ["gangbang"]=3, ["orgy"]=3,
    ["porn"]=3, ["porno"]=3, ["pron"]=3, ["pr0n"]=3, ["hentai"]=3,
    ["nsfw"]=3, ["milf"]=3, ["dilf"]=3, ["bdsm"]=3, ["fetish"]=3,
    ["horny"]=3, ["orgasm"]=3, ["masturbate"]=3, ["masturbation"]=3,
    ["whore"]=3, ["hoe"]=3, ["hoes"]=3, ["slut"]=3, ["sluts"]=3,
    ["skank"]=3, ["hooker"]=3, ["prostitute"]=3, ["escort"]=2,
    ["rape"]=3, ["rapist"]=3, ["molest"]=3, ["pedo"]=3, ["pedophile"]=3,
    ["incest"]=3, ["bestiality"]=3, ["zoophilia"]=3, ["cp"]=3,

    -- berat: hinaan identitas
    ["nigga"]=3, ["niggas"]=3, ["nigger"]=3, ["niggers"]=3, ["nigg"]=3,
    ["n1gga"]=3, ["chink"]=3, ["gook"]=3, ["spic"]=3, ["wetback"]=3,
    ["kike"]=3, ["raghead"]=3, ["towelhead"]=3, ["paki"]=3, ["coon"]=3,
    ["faggot"]=3, ["fag"]=3, ["fags"]=3, ["faggy"]=3, ["dyke"]=3,
    ["tranny"]=3, ["shemale"]=3, ["retard"]=3, ["retarded"]=3, ["tard"]=3,
    ["spastic"]=3, ["cripple"]=3, ["midget"]=2,

    -- sedang: umpatan
    ["fuck"]=2, ["fucks"]=2, ["fucked"]=2, ["fucking"]=2, ["fucker"]=2,
    ["fuckers"]=2, ["fuk"]=2, ["fuc"]=2, ["fck"]=2, ["fcking"]=2,
    ["fkn"]=2, ["fking"]=2, ["stfu"]=2, ["wtf"]=1, ["af"]=1, ["mf"]=2,
    ["motherfucker"]=3, ["mofo"]=2, ["mfer"]=2, ["fu"]=2, ["fuq"]=2,
    ["shit"]=2, ["shite"]=2, ["shitty"]=2, ["shits"]=2, ["sht"]=2,
    ["bullshit"]=2, ["bs"]=1, ["crap"]=1, ["crappy"]=1, ["turd"]=1,
    ["bitch"]=2, ["bitches"]=2, ["btch"]=2, ["biatch"]=2, ["bish"]=1,
    ["bastard"]=2, ["bastards"]=2, ["asshole"]=2, ["assholes"]=2,
    ["arsehole"]=2, ["ass"]=2, ["arse"]=2, ["asses"]=2, ["jackass"]=2,
    ["dumbass"]=2, ["badass"]=1, ["smartass"]=1, ["dipshit"]=2,
    ["damn"]=1, ["dammit"]=1, ["goddamn"]=2, ["hell"]=1, ["bloody"]=1,
    ["bugger"]=2, ["bollocks"]=2, ["prick"]=2, ["knob"]=2, ["git"]=1,
    ["wth"]=1, ["omfg"]=1, ["piss"]=2, ["pissed"]=1, ["pissing"]=2,
    ["douche"]=2, ["douchebag"]=2, ["scumbag"]=2, ["slag"]=2,

    -- ringan
    ["stupid"]=1, ["idiot"]=1, ["idiots"]=1, ["moron"]=1, ["morons"]=1,
    ["dumb"]=1, ["dumber"]=1, ["loser"]=1, ["losers"]=1, ["noob"]=1,
    ["nub"]=1, ["trash"]=1, ["garbage"]=1, ["ugly"]=1, ["fatty"]=1,
    ["freak"]=1, ["weirdo"]=1, ["creep"]=1, ["simp"]=1, ["incel"]=1,
    ["cringe"]=1, ["sucks"]=1, ["suck"]=1, ["lame"]=1, ["pathetic"]=1,
    ["scrub"]=1, ["bot"]=1, ["skid"]=1, ["leech"]=1,
}

--=============================================================================
-- INGGRIS -- POTONGAN
--=============================================================================
local EN_POTONG = {
    ["fucking"]=2, ["fucker"]=2, ["motherfuck"]=3, ["bullshit"]=2,
    ["asshole"]=2, ["arsehole"]=2, ["dumbass"]=2, ["jackass"]=2,
    ["bitches"]=2, ["bastard"]=2, ["faggot"]=3, ["nigger"]=3, ["nigga"]=3,
    ["retard"]=3, ["blowjob"]=3, ["handjob"]=3, ["gangbang"]=3,
    ["masturbat"]=3, ["prostitut"]=3, ["pedophil"]=3, ["whore"]=3,
    ["douchebag"]=2, ["cocksuck"]=3, ["dickhead"]=3, ["shithead"]=2,
}

--=============================================================================
-- DAFTAR PUTIH
--=============================================================================
-- Kata sah yang MENGANDUNG entri di atas. Diperiksa DULUAN: kalau teks yang
-- sudah dinormalisasi cocok salah satu di sini, kata itu dilewati.
--
-- Ini bagian yang paling sering dilupakan orang, dan akibatnya paling terasa:
-- satu pemakai yang kena ban karena mengetik "kasur" merusak kepercayaan pada
-- seluruh sistem moderasi.
local PUTIH = {
    -- ID: mengandung "asu"
    "kasur", "asuransi", "asuh", "mengasuh", "pengasuh", "asupan", "basuh",
    "masuk", "kemasukan", "asumsi", "asuransikan",
    -- ID: mengandung "tai"
    "pantai", "sampai", "detail", "petai", "taiwan", "tailor", "retail",
    "cocktail", "mentai", "santai", "tetap", "taat",
    -- ID: mengandung "coli"
    "brokoli", "colin", "policy", "coliform",
    -- ID: mengandung "memek"
    "memekik", "memekikkan",
    -- ID: mengandung "babi"
    "babirusa", "kebab", "kebabi",
    -- ID: mengandung "su"/"cok"/"cuk"
    "sudah", "susah", "suka", "sungai", "cokelat", "coklat", "cukup",
    "mencukupi", "sukses", "susun", "cukur", "bangsa", "bangsawan",
    "kontrol", "terkontrol", "gilang", "gilir", "keterampilan",
    -- EN: mengandung "ass"
    "class", "classes", "classic", "pass", "passed", "password", "passion",
    "bass", "brass", "grass", "glass", "mass", "massive", "compass",
    "embassy", "assassin", "assist", "assistant", "assume", "assumption",
    "assess", "asset", "assign", "association", "cassette", "harass",
    "potassium", "molasses", "carcass", "surpass", "bypass", "canvass",
    -- EN: mengandung "hell"
    "hello", "shell", "shelly", "michelle", "hellenic", "othello", "seashell",
    -- EN: mengandung "cock"
    "cockpit", "peacock", "cockroach", "cocktail", "hancock", "shuttlecock",
    -- EN: mengandung "anal"
    "analysis", "analyst", "analyze", "analytics", "canal", "banal",
    -- EN: mengandung "cum"
    "document", "cucumber", "circumstance", "accumulate", "incumbent",
    "cumulative", "scum",
    -- EN: lain-lain
    "button", "butter", "shiitake", "titan", "titanic", "title", "constitute",
    "substitute", "institute", "magnificent", "dickens", "uranus", "penistone",
    "skyscraper", "grape", "therapist", "therapy", "bassoon", "sixth",
}

--=============================================================================
-- NORMALISASI
--=============================================================================
local LEET = {
    ["4"]="a", ["@"]="a", ["8"]="b", ["("]="c", ["3"]="e", ["6"]="g",
    ["9"]="g", ["1"]="i", ["!"]="i", ["|"]="i", ["0"]="o", ["5"]="s",
    ["$"]="s", ["7"]="t", ["+"]="t", ["2"]="z", ["#"]="h",
}

-- DASAR: huruf kecil + angka/simbol pengganti dikembalikan.
function Kotor.Dasar(teks)
    return (tostring(teks or ""):lower():gsub(".", function(c) return LEET[c] or c end))
end

-- TIPIS: dasar, lalu deretan huruf yang SAMA sepanjang TIGA ATAU LEBIH
-- dipendekkan jadi satu. Deretan DUA dibiarkan.
--
-- Batasnya tiga, bukan dua, dan itu bukan selera: banyak kata sah punya huruf
-- ganda ("pass", "hello", "boobs", "rapat"), dan memendekkan di dua membuat
-- "boobs" jadi "bobs" -- nama orang berubah jadi kata kotor.
--
-- DITULIS TANPA BACK-REFERENCE. Pola `(%a)%1%1+` yang wajar dibayangkan itu
-- TIDAK JALAN di Lua: back-reference tidak boleh diberi kuantifier, dan
-- gsub-nya diam-diam tidak mencocokkan apa pun -- "anjiiiing" lolos bulat.
local function pendekkan(s)
    local out, i, n = {}, 1, #s
    while i <= n do
        local c = s:sub(i, i)
        local j = i
        while j < n and s:sub(j + 1, j + 1) == c do j = j + 1 end
        out[#out + 1] = ((j - i + 1) >= 3) and c or s:sub(i, j)
        i = j + 1
    end
    return table.concat(out)
end

function Kotor.Tipis(teks)
    return pendekkan(Kotor.Dasar(teks))
end

-- RAPAT: tipis tanpa karakter selain huruf. Ini yang menangkap "a n j i n g",
-- "a.n.j.i.n.g", "b*a*n*g*s*a*t".
function Kotor.Rapat(teks)
    return (Kotor.Tipis(teks):gsub("[^%a]", ""))
end

--=============================================================================
-- INDEKS
--=============================================================================
-- Kunci kamus ikut dinormalisasi, sekali saat modul lahir. Kalau tidak,
-- "anjiiiing" yang sudah dipendekkan jadi "anjing" diadu dengan kunci yang
-- belum dipendekkan -- dua bentuk yang berbeda untuk kata yang sama.
local UTUH, POTONG, PUTIH_T = {}, {}, {}

local function serap(dari, ke)
    for kata, t in pairs(dari) do
        local k = Kotor.Tipis(kata)
        if (ke[k] or 0) < t then ke[k] = t end
    end
end
serap(ID_UTUH, UTUH) ; serap(EN_UTUH, UTUH)
serap(ID_POTONG, POTONG) ; serap(EN_POTONG, POTONG)
for _, p in ipairs(PUTIH) do PUTIH_T[#PUTIH_T + 1] = Kotor.Tipis(p) end

--=============================================================================
-- PEMERIKSAAN
--=============================================================================
-- PANJANG MINIMAL untuk pencocokan di kalimat yang dirapatkan. Di bawah ini
-- kecocokannya hampir selalu palsu: merapatkan "class is" melahirkan "ass",
-- merapatkan "the rapist" melahirkan "rapist". Empat huruf menahan yang
-- pertama; yang kedua ditahan daftar putih.
local MIN_RAPAT = 4

-- Mengembalikan tingkat tertinggi yang ditemukan (0 = bersih) dan kata yang
-- memicunya. Bukan sekadar true/false -- moderator perlu tahu kata APA yang
-- kena, kalau tidak setiap sanggahan berakhir jadi tebak-tebakan.
function Kotor.Periksa(teks, ambang)
    ambang = ambang or Kotor.SEDANG
    local tinggi, pemicu = 0, nil

    -- TAHAP 1: per kata, diadu utuh.
    --
    -- TANPA DAFTAR PUTIH, dan itu disengaja. Daftar putih di sini pernah ada
    -- dan justru merusak: pemeriksaannya "apakah kata ini MENGANDUNG entri
    -- putih", sehingga "bangsat" ditolak karena mengandung "bangsa". Di tahap
    -- ini daftar putih memang tidak diperlukan -- "kasur" bukan "asu", dan
    -- pencocokan utuh sudah menolaknya sendiri.
    for kata in Kotor.Tipis(teks):gmatch("[%a]+") do
        local t = UTUH[kata]
        if t and t >= ambang and t > tinggi then tinggi, pemicu = t, kata end
    end

    -- TAHAP 2: seluruh kalimat dirapatkan, untuk menangkap penyamaran spasi.
    --
    -- Daftar putih dipakai di sini lewat TUMPANG-TINDIH RENTANG: kecocokan
    -- kotor diabaikan hanya kalau seluruhnya berada DI DALAM kata sah.
    --
    -- Dua cara yang lebih sederhana sudah dicoba dan dua-duanya salah:
    --
    --   * "tolak seluruh teks kalau ada kata putih" -- satu kata "hello" cukup
    --     untuk meloloskan umpatan apa pun di kalimat yang sama.
    --   * "hapus kata putih dari teks rapat lebih dulu" -- TERUKUR: "bangsa"
    --     ikut terhapus dari "bangsat" dan menyisakan "t", jadi
    --     "b*a*n*g*s*a*t" lolos bulat. Kata sah yang merupakan awalan kata
    --     kotor menghancurkan kata kotornya.
    local rapat = Kotor.Rapat(teks)

    local aman_rentang = {}
    for _, p in ipairs(PUTIH_T) do
        if #p >= 4 then
            local dari = 1
            while true do
                local a, b = rapat:find(p, dari, true)
                if not a then break end
                aman_rentang[#aman_rentang + 1] = { a, b }
                dari = a + 1
            end
        end
    end

    local function tertutup(a, b)
        for _, v in ipairs(aman_rentang) do
            if v[1] <= a and v[2] >= b then return true end
        end
        return false
    end

    local function sisir(daftar, minimal)
        for pola, t in pairs(daftar) do
            if t >= ambang and t > tinggi and #pola >= minimal then
                local dari = 1
                while true do
                    local a, b = rapat:find(pola, dari, true)
                    if not a then break end
                    if not tertutup(a, b) then tinggi, pemicu = t, pola break end
                    dari = a + 1
                end
            end
        end
    end
    sisir(POTONG, 1)
    sisir(UTUH, MIN_RAPAT)

    return tinggi, pemicu
end

function Kotor.Kotor(teks, ambang)
    return (Kotor.Periksa(teks, ambang)) > 0
end

-- Apakah potongan ini bagian dari kata sah? Arahnya: kata yang diperiksa harus
-- BERADA DI DALAM entri putih, bukan sebaliknya.
local function aman(kata)
    for _, p in ipairs(PUTIH_T) do
        if p == kata or p:find(kata, 1, true) then return true end
    end
    return false
end

-- Menyensor sambil mempertahankan bentuk aslinya: hanya potongan yang cocok
-- yang diganti, tanda baca dan besar-kecil huruf lain tidak disentuh.
function Kotor.Sensor(teks, ambang, ganti)
    ambang, ganti = ambang or Kotor.SEDANG, ganti or "*"
    return (tostring(teks or ""):gsub("[%a%d@!|$+#]+", function(potongan)
        local kata = Kotor.Tipis(potongan)
        if aman(kata) then return potongan end
        local t = UTUH[kata]
        if t and t >= ambang then return ganti:rep(#potongan) end
        for pola, tt in pairs(POTONG) do
            if tt >= ambang and kata:find(pola, 1, true) then
                return ganti:rep(#potongan)
            end
        end
        return potongan
    end))
end

-- Dibuka supaya pemakai bisa menambah entri sendiri tanpa menyunting berkas
-- ini -- daftar yang harus disunting untuk setiap kata baru tidak akan pernah
-- diperbarui.
Kotor.ID_UTUH, Kotor.ID_POTONG = ID_UTUH, ID_POTONG
Kotor.EN_UTUH, Kotor.EN_POTONG = EN_UTUH, EN_POTONG
Kotor.PUTIH = PUTIH

-- Menulis ke kamus MENTAH sekaligus ke indeks yang sudah dinormalisasi.
-- Menulis ke salah satunya saja berarti kata baru tidak pernah ikut diperiksa
-- -- indekslah yang dibaca `Periksa`, bukan kamus mentahnya.
function Kotor.Tambah(kata, tingkat, potongan)
    local k = Kotor.Tipis(kata)
    if potongan then ID_POTONG[k], POTONG[k] = tingkat, tingkat
    else ID_UTUH[k], UTUH[k] = tingkat, tingkat end
end

function Kotor.Putihkan(kata)
    local k = Kotor.Tipis(kata)
    PUTIH[#PUTIH + 1], PUTIH_T[#PUTIH_T + 1] = k, k
end

return Kotor
