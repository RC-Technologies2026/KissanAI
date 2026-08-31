/// Comprehensive Pakistan location data: Province → District → Cities/Tehsils.
/// Used by Register, Edit Profile, and Weather screens.
class PakistanLocations {
  PakistanLocations._();

  static const List<String> provinces = [
    'Punjab',
    'Sindh',
    'Khyber Pakhtunkhwa',
    'Balochistan',
    'Gilgit-Baltistan',
    'Azad Kashmir',
    'Islamabad Capital Territory',
  ];

  static const Map<String, Map<String, List<String>>> data = {
    // ═══════════════════════════════════════════════════════════
    // PUNJAB — 36 Districts
    // ═══════════════════════════════════════════════════════════
    'Punjab': {
      'Attock': ['Attock City', 'Hazro', 'Jand', 'Kamra', 'Pind Dadan Khan'],
      'Bahawalnagar': ['Bahawalnagar City', 'Chishtian', 'Fort Abbas', 'Haroonabad'],
      'Bahawalpur': ['Bahawalpur City', 'Ahmadpur East', 'Yazman', 'Khairpur Tamewali'],
      'Bhakkar': ['Bhakkar City', 'Darya Khan', 'Kallur Kot', 'Mankera'],
      'Chakwal': ['Chakwal City', 'Choa Saidan Shah', 'Kallar Kahar', 'Talagang'],
      'Chiniot': ['Chiniot City', 'Bhawana', 'Lalian', 'Rabwah'],
      'Dera Ghazi Khan': ['DG Khan City', 'Taunsa', 'Kot Chaddu', 'Dajal'],
      'Faisalabad': ['Faisalabad City', 'Jaranwala', 'Sammundri', 'Tandlianwala', 'Chak Jhumra'],
      'Gujranwala': ['Gujranwala City', 'Kamoke', 'Nowshera Virkan', 'Wazirabad'],
      'Gujrat': ['Gujrat City', 'Jalalpur Jattan', 'Kharian', 'Sarai Alamgir'],
      'Hafizabad': ['Hafizabad City', 'Pindigheb', 'Naushahra Virkan'],
      'Jhang': ['Jhang City', 'Shorkot', 'Ahmadpur Sial', 'Athara Hazari'],
      'Jhelum': ['Jhelum City', 'Dina', 'Sohawa', 'Pind Dadan Khan'],
      'Kasur': ['Kasur City', 'Chunian', 'Pattoki', 'Kot Radha Kishan'],
      'Khanewal': ['Khanewal City', 'Mian Channu', 'Kabirwala', 'Talamba'],
      'Khushab': ['Khushab City', 'Jauharabad', 'Nurpur Thal', 'Quaidabad'],
      'Lahore': ['Lahore City', 'Model Town', 'Cantt', 'Shalimar', 'Wagah'],
      'Layyah': ['Layyah City', 'Karor Lal Esan', 'Chaubara'],
      'Lodhran': ['Lodhran City', 'Dunyapur', 'Kahror Pacca', 'Jahanian'],
      'Mandi Bahauddin': ['Mandi Bahauddin City', 'Phalia', 'Malakwal', 'Bhalwal'],
      'Mianwali': ['Mianwali City', 'Isa Khel', 'Pipplan', 'Kundian'],
      'Multan': ['Multan City', 'Shujabad', 'Jalalpur Pirwala', 'Burewala'],
      'Muzaffargarh': ['Muzaffargarh City', 'Kot Addu', 'Alipur', 'Jatoi'],
      'Nankana Sahib': ['Nankana Sahib City', 'Sangla Hill', 'Khanqah Dogran'],
      'Narowal': ['Narowal City', 'Shakargarh', 'Zafarwal', 'Fazilpur'],
      'Okara': ['Okara City', 'Depalpur', 'Renala Khurd', 'Basirpur'],
      'Pakpattan': ['Pakpattan City', 'Arifwala', 'Bahadurgarh'],
      'Rahim Yar Khan': ['Rahim Yar Khan City', 'Sadiqabad', 'Khanpur', 'Sheikhupura'],
      'Rajanpur': ['Rajanpur City', 'Dajal', 'Fazalpur', 'Rojan'],
      'Rawalpindi': ['Rawalpindi City', 'Gujar Khan', 'Taxila', 'Kahuta', 'Murree'],
      'Sahiwal': ['Sahiwal City', 'Chichawatni', 'Iqbal Nagar'],
      'Sargodha': ['Sargodha City', 'Bhalwal', 'Shahpur', 'Kot Momin', 'Bhera'],
      'Sheikhupura': ['Sheikhupura City', 'Ferozewala', 'Muridke', 'Nankana'],
      'Sialkot': ['Sialkot City', 'Daska', 'Pasrur', 'Kotli Loharan'],
      'Toba Tek Singh': ['Toba Tek Singh City', 'Gojra', 'Kamalia', 'Pir Mahal'],
      'Vehari': ['Vehari City', 'Burewala', 'Mailsi', 'Hasilpur'],
    },

    // ═══════════════════════════════════════════════════════════
    // SINDH — 30 Districts
    // ═══════════════════════════════════════════════════════════
    'Sindh': {
      'Badin': ['Badin City', 'Tando Bago', 'Matli', 'Shaheed Fazil Rahu'],
      'Dadu': ['Dadu City', 'Johi', 'Mehar', 'Khairpur Nathan Shah'],
      'Ghotki': ['Ghotki City', 'Mirpur Mathelo', 'Daharki', 'Khanpur'],
      'Hyderabad': ['Hyderabad City', 'Latifabad', 'Qasimabad', 'Hala', 'Tando Muhammad Khan'],
      'Jacobabad': ['Jacobabad City', 'Shikarpur', 'Kandhkot', 'Kashmore'],
      'Jamshoro': ['Jamshoro City', 'Manjhand', 'Sehwan', 'Kotri'],
      'Karachi': ['Karachi City', 'Korangi', 'Malir', 'Lyari', 'Saddar', 'Gulshan'],
      'Kashmore': ['Kashmore City', 'Kandhkot', 'Tangwani', 'Machar'],
      'Khairpur': ['Khairpur City', 'Kot Diji', 'Sobhodero', 'Nara'],
      'Larkana': ['Larkana City', 'Ratodero', 'Naudero', 'Bakrani'],
      'Matiari': ['Matiari City', 'Hala', 'Saeedabad', 'Sann'],
      'Mirpurkhas': ['Mirpurkhas City', 'Digri', 'Kot Ghulam Muhammad', 'Jhuddo'],
      'Naushahro Feroze': ['Naushahro Feroze City', 'Moro', 'Bhiria', 'Kandiaro'],
      'Nawabshah': ['Nawabshah City', 'Sakrand', 'Daur', 'Qazi Ahmad'],
      'Qambar Shahdadkot': ['Qambar City', 'Shahdadkot', 'Mirokhan', 'Nasirabad'],
      'Sanghar': ['Sanghar City', 'Tando Adam', 'Chachro', 'Dhoro Naro'],
      'Shikarpur': ['Shikarpur City', 'Lakhi', 'Garhi Yasin', 'Khanpur'],
      'Sukkur': ['Sukkur City', 'Rohri', 'Pano Aqil', 'Saleh Pat'],
      'Tando Allahyar': ['Tando Allahyar City', 'Chamber', 'Jhando Mari'],
      'Tando Muhammad Khan': ['Tando Muhammad Khan City', 'Bulri', 'Talhar'],
      'Tharparkar': ['Mithi City', 'Chachro', 'Diplo', 'Nangarparkar'],
      'Thatta': ['Thatta City', 'Mirpur Batoro', 'Kharano', 'Ghorabari'],
      'Umerkot': ['Umerkot City', 'Kunri', 'Pithoro', 'Samaro'],
    },

    // ═══════════════════════════════════════════════════════════
    // KHYBER PAKHTUNKHWA — 35 Districts
    // ═══════════════════════════════════════════════════════════
    'Khyber Pakhtunkhwa': {
      'Abbottabad': ['Abbottabad City', 'Havelian', 'Thandiani', 'Shingrai'],
      'Bannu': ['Bannu City', 'Domel', 'Kakki', 'Miryan'],
      'Batagram': ['Batagram City', 'Allai', 'Banna'],
      'Buner': ['Buner City', 'Daggar', 'Chagharzai', 'Gagra'],
      'Charsadda': ['Charsadda City', 'Tangi', 'Shabqadar', 'Utmanzai'],
      'Chitral': ['Chitral City', 'Drosh', 'Mastuj', 'Bir'],
      'Dera Ismail Khan': ['DI Khan City', 'Kulachi', 'Paharpur', 'Daraban'],
      'Hangu': ['Hangu City', 'Thal', 'Saghara'],
      'Haripur': ['Haripur City', 'Ghazi', 'Khanpur', 'Tarbella'],
      'Karak': ['Karak City', 'Takht-e-Nasrati', 'Banu', 'Chhachra'],
      'Kohat': ['Kohat City', 'Lachi', 'Shahpur', 'Gumbat'],
      'Kohistan': ['Kohistan City', 'Dasu', 'Pattan', 'Palas'],
      'Lakki Marwat': ['Lakki Marwat City', 'Ghazni Khel', 'Bettani'],
      'Lower Dir': ['Timergara City', 'Adinzai', 'Balambat', 'Munda'],
      'Lower Kohistan': ['Pattan City', 'Banna', 'Dassu'],
      'Malakand': ['Malakand City', 'Batkhela', 'Dheri', 'Thana'],
      'Mardan': ['Mardan City', 'Takht-i-Bahi', 'Katlang', 'Rustam'],
      'Mansehra': ['Mansehra City', 'Shinkiari', 'Oghi', 'Baffa'],
      'Nowshera': ['Nowshera City', 'Risalpur', 'Jehangira', 'Pabbi'],
      'Peshawar': ['Peshawar City', 'Hayatabad', 'University Town', 'Cantt', 'Badaber'],
      'Shangla': ['Shangla City', 'Alpuri', 'Martung', 'Purran'],
      'Swabi': ['Swabi City', 'Topi', 'Lahor', 'Razar'],
      'Swat': ['Saidu Sharif', 'Mingora', 'Matta', 'Kabal', 'Charbagh'],
      'Tank': ['Tank City', 'Gomal', 'Tatta', 'Zara'],
      'Tor Ghar': ['Tor Ghar City', 'Jabba', 'Chach'],
      'Upper Dir': ['Dir City', 'Wari', 'Barikot', 'Kalkot'],
      'Upper Kohistan': ['Dasu City', 'Pattan', 'Banna'],
    },

    // ═══════════════════════════════════════════════════════════
    // BALOCHISTAN — 34 Districts
    // ═══════════════════════════════════════════════════════════
    'Balochistan': {
      'Awaran': ['Awaran City', 'Jhal Jhao', 'Mashkai'],
      'Barkhan': ['Barkhan City', 'Barkhan Town', 'Phulghan'],
      'Chagai': ['Chagai City', 'Dalbandin', 'Nushki', 'Taftan'],
      'Dera Bugti': ['Dera Bugti City', 'Phelwan', 'Pir Koh'],
      'Gwadar': ['Gwadar City', 'Ormara', 'Pasni', 'Jiwani'],
      'Harnai': ['Harnai City', 'Sharigh', 'Ziarat'],
      'Jafarabad': ['Jafarabad City', 'Dera Allahyar', 'Sohbatpur'],
      'Jhal Magsi': ['Jhal Magsi City', 'Gandava', 'Bhag'],
      'Kachhi': ['Kachhi City', 'Dhadar', 'Mach', 'Bolan'],
      'Kalat': ['Kalat City', 'Mastung', 'Nal', 'Gazg'],
      'Kech': ['Turbat City', 'Gwadar', 'Pasni', 'Jiwani'],
      'Kharan': ['Kharan City', 'Mashkel', 'Nokundi'],
      'Khuzdar': ['Khuzdar City', 'Wadh', 'Moola', 'Zehri'],
      'Killa Abdullah': ['Killa Abdullah City', 'Chaman', 'Gulistan'],
      'Killa Saifullah': ['Killa Saifullah City', 'Muslim Bagh', 'Badini'],
      'Kolalu': ['Kolalu City', 'Kohlu', 'Tamboo'],
      'Lasbela': ['Lasbela City', 'Uthal', 'Bela', 'Sonmiani'],
      'Loralai': ['Loralai City', 'Barkhan', 'Tordher'],
      'Musa Khel': ['Musa Khel City', 'Kakar', 'Babaran'],
      'Nasirabad': ['Nasirabad City', 'Dera Murad Jamali', 'Tamboo'],
      'Nushki': ['Nushki City', 'Dalbandin', 'Chagai'],
      'Panjgur': ['Panjgur City', 'Tump', 'Gichki'],
      'Pishin': ['Pishin City', 'Barshore', 'Saranan'],
      'Quetta': ['Quetta City', 'Chaman', 'Pishin', 'Mastung'],
      'Sherani': ['Sherani City', 'Babar', 'Khwazhakela'],
      'Sibi': ['Sibi City', 'Dhadar', 'Mach', 'Harnai'],
      'Washuk': ['Washuk City', 'Besima', 'Nok Kundi'],
      'Zhob': ['Zhob City', 'Kakar', 'Qamar Din Karez'],
      'Ziarat': ['Ziarat City', 'Kawas', 'Sanjavi'],
    },

    // ═══════════════════════════════════════════════════════════
    // GILGIT-BALTISTAN — 10 Districts
    // ═══════════════════════════════════════════════════════════
    'Gilgit-Baltistan': {
      'Astore': ['Astore City', 'Minimarg', 'Rupikot'],
      'Diamer': ['Chilas City', 'Babusar', 'Tangir'],
      'Ghizer': ['Ghizer City', 'Gupis', 'Ishkoman', 'Phander'],
      'Gilgit': ['Gilgit City', 'Jutial', 'Hunza', 'Nagar'],
      'Gupis-Yasin': ['Gupis City', 'Yasin', 'Phander'],
      'Hunza': ['Karimabad City', 'Aliabad', 'Passu', 'Sost'],
      'Kharmang': ['Kharmang City', 'Tolti', 'Mashabrum'],
      'Nagar': ['Nagar City', 'Chalt', 'Hopar'],
      'Shigar': ['Shigar City', 'Skardu', 'Askole'],
      'Skardu': ['Skardu City', 'Kharmang', 'Rondhu'],
    },

    // ═══════════════════════════════════════════════════════════
    // AZAD KASHMIR — 10 Districts
    // ═══════════════════════════════════════════════════════════
    'Azad Kashmir': {
      'Bagh': ['Bagh City', 'Dhirkot', 'Hari Ghel'],
      'Bhimber': ['Bhimber City', 'Barnala', 'Samahni'],
      'Haveli': ['Haveli City', 'Forward Kahuta', 'Rawalakot'],
      'Kotli': ['Kotli City', 'Sehnsa', 'Charhoi'],
      'Mirpur': ['Mirpur City', 'Dhirkot', 'Barnala'],
      'Muzaffarabad': ['Muzaffarabad City', 'Pattika', 'Nasrotabad'],
      'Neelum': ['Neelum City', 'Athmuqam', 'Sharda', 'Kel'],
      'Poonch': ['Poonch City', 'Rawalakot', 'Hajira'],
      'Sudhanoti': ['Sudhanoti City', 'Pallandri', 'Mangla'],
      'Hattian': ['Hattian City', 'Chikkar', 'Dhirkot'],
    },

    // ═══════════════════════════════════════════════════════════
    // ISLAMABAD CAPITAL TERRITORY
    // ═══════════════════════════════════════════════════════════
    'Islamabad Capital Territory': {
      'Islamabad': ['Islamabad City', 'Bani Gala', 'Bharakahu', 'Sihala', 'Nilore'],
    },
  };

  /// Get all districts for a province.
  static List<String> districtsOf(String province) =>
      data[province]?.keys.toList() ?? [];

  /// Get all cities/tehsils for a district in a province.
  static List<String> citiesOf(String province, String district) =>
      data[province]?[district] ?? [];
}
