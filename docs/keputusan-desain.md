# Tabel Keputusan Desain Fire Smart Alarm

Dokumen ini berisi keputusan desain yang diterapkan dalam pengembangan sistem Fire Smart Alarm, beserta alasan pemilihan setiap keputusan.

| No. | Keputusan Desain | Alasan |
| --- | --- | --- |
| 1 | Menggunakan ESP32 sebagai mikrokontroler utama. | ESP32 dapat membaca data sensor dan mengirimkan data melalui jaringan Wi-Fi. |
| 2 | Menggunakan sensor MQ-2 dan DHT22. | MQ-2 digunakan untuk membaca indikator asap/gas, sedangkan DHT22 digunakan untuk mengukur suhu dan kelembapan. |
| 3 | Menggunakan tiga status kondisi, yaitu Normal, Warning, dan Danger. | Memudahkan pengguna memahami kondisi laboratorium berdasarkan hasil pembacaan dan pemrosesan data sensor. |
| 4 | Menggunakan Firebase Firestore sebagai penyimpanan data sensor. | Memungkinkan data sensor disimpan dan diakses oleh aplikasi melalui internet. |
| 5 | Menggunakan Flutter untuk mengembangkan aplikasi Android dan web. | Memungkinkan pemantauan kondisi laboratorium melalui aplikasi pada perangkat yang didukung. |
| 6 | Menggunakan Firebase Cloud Messaging (FCM) untuk push notification. | Memungkinkan sistem mengirimkan peringatan ke perangkat Android ketika kondisi memenuhi aturan notifikasi. |
| 7 | Menggunakan buzzer dan LED sebagai peringatan lokal. | Memberikan tanda peringatan secara langsung di lokasi ketika sistem mendeteksi kondisi Danger. |