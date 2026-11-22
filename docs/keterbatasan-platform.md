Catatan Keterbatasan Platform Fire Smart Alarm

1.  Keterbatasan Koneksi Internet
    Pengiriman data sensor dari ESP32 ke Firebase Firestore memerlukan koneksi Wi-Fi dan akses internet. Apabila koneksi terputus, pengiriman data terbaru dapat terganggu.

2.  Keterbatasan Push Notification
    Pengiriman push notification bergantung pada koneksi internet dan layanan Firebase Cloud Messaging. Notifikasi dapat mengalami keterlambatan ketika perangkat penerima offline. Notifikasi yang tertunda dapat diterima kembali setelah koneksi pulih, bergantung pada kondisi dan kebijakan pengiriman pesan.

3.  Ketergantungan pada Python Notifier
    Pada implementasi saat ini, program Python berjalan di komputer untuk memantau perubahan status di Firestore dan mengirimkan push notification. Oleh karena itu, komputer, program notifier, dan koneksi internet perlu tersedia agar proses pemantauan serta pengiriman notifikasi dapat berjalan.

4.  Keterbatasan Pembacaan Sensor
    Pembacaan sensor MQ-2 dan DHT22 dapat dipengaruhi kondisi lingkungan, kalibrasi, penempatan sensor, dan karakteristik perangkat. Nilai sensor perlu diuji agar penentuan status sesuai dengan kondisi yang ingin dipantau.

5.  Keterbatasan Pengujian
    Pengujian prototipe dilakukan berdasarkan perangkat, jaringan, dan kondisi pengujian yang tersedia. Hasil pengujian belum dapat menjamin bahwa sistem akan selalu memberikan peringatan tanpa keterlambatan atau kesalahan dalam seluruh kondisi penggunaan.

6.  Keterbatasan Peringatan
    Fire Smart Alarm merupakan prototipe pemantauan dan peringatan dini. Sistem tidak menggantikan sistem deteksi kebakaran bersertifikasi dan prosedur keselamatan laboratorium.

7.  Ketergantungan pada Sumber Daya Listrik
    Perangkat Fire Smart Alarm bergantung pada sumber daya listrik untuk mengoperasikan ESP32, sensor MQ-2, DHT22, serta komponen peringatan lokal berupa buzzer dan LED. Apabila terjadi pemadaman listrik, perangkat tidak dapat melakukan pembacaan sensor, memproses kondisi lingkungan, maupun memberikan peringatan lokal. Kondisi ini juga menyebabkan pengiriman data sensor terbaru ke Firebase Firestore terhenti selama perangkat tidak beroperasi. Sistem belum dilengkapi dengan sumber daya cadangan untuk menjaga perangkat tetap berfungsi ketika listrik padam.