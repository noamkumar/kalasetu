import sys
import os

# Add backend directory to path
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.db.base import Base
from app.db.session import engine, SessionLocal
from app.models.db_models import Artisan, Product, ProductTranslation, Order, OrderItem

def seed():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    # Clear existing data for fresh seed
    db.query(OrderItem).delete()
    db.query(Order).delete()
    db.query(ProductTranslation).delete()
    db.query(Product).delete()
    db.query(Artisan).delete()
    db.commit()

    print("Seeding artisans...")
    # 1. Primary Demo Artisan
    artisan_ramesh = Artisan(
        id="artisan_ramesh_kutch",
        phone="9876543210",
        name="Ramesh Bhai Vankar",
        craft_type="Handloom",
        cluster_location="Bhujodi, Kutch",
        state="Gujarat",
        experience_years=24,
        pehchan_id="PEH-GJ-2023-8841",
        preferred_language="hi",
        bank_account_holder="Ramesh Bhai Vankar",
        bank_account_number="102938475612",
        bank_ifsc="SBIN0001234",
        bank_name="State Bank of India",
    )
    # 2. Secondary Demo Artisan
    artisan_ananya = Artisan(
        id="artisan_ananya_jaipur",
        phone="9812345678",
        name="Ananya Sharma",
        craft_type="Pottery",
        cluster_location="Kot Jewar, Jaipur",
        state="Rajasthan",
        experience_years=14,
        pehchan_id="PEH-RJ-2022-4912",
        preferred_language="en",
        bank_account_holder="Ananya Sharma",
        bank_account_number="987654321098",
        bank_ifsc="HDFC0000456",
        bank_name="HDFC Bank",
    )
    db.add(artisan_ramesh)
    db.add(artisan_ananya)
    db.commit()

    print("Seeding 12 craft products with 6-language translations...")
    products_data = [
        {
            "id": "prod_blue_pottery_vase",
            "artisan_id": artisan_ananya.id,
            "category": "Pottery",
            "price": 1450.0,
            "cost_price": 620.0,
            "stock_quantity": 5,
            "primary_image_url": "https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?auto=format&fit=crop&w=600&q=80",
            "translations": {
                "en": ("Jaipur Blue Pottery Floral Vase", "Handcrafted traditional turquoise blue quartz-frit vase featuring Persian floral motifs. Fired without clay using Egyptian paste technique."),
                "hi": ("जयपुर ब्लू पॉटरी फ्लोरल फूलदान", "पारंपरिक फिरोजी नीले क्वार्ट्ज का हस्तनिर्मित फूलदान, फारसी फूलों के रूपांकनों से सुसज्जित। बिना मिट्टी के विशेष तकनीक से तैयार।"),
                "ta": ("ஜெய்ப்பூர் நீல மட்பாண்ட மலர் குவளை", "பாரம்பரிய டர்க்காய்ஸ் நீல குவார்ட்ஸ் பூந்தொட்டி, பெர்சிய மலர் வடிவமைப்புடன் கைகளால் செய்யப்பட்டது."),
                "te": ("జైపూర్ బ్లూ పాట్ ఫ్లవర్ వాజ్", "సాంప్రదాయ టర్కోయిస్ నీలం రంగు క్వార్ట్జ్ పూల కుండీ, పర్షియన్ పూల నమూనాలతో చేతితో తయారు చేయబడింది."),
                "kn": ("ಜೈಪುರ ನೀಲಿ ಮಣ್ಣಿನ ಹೂದಾನಿ", "ಸಾಂಪ್ರದಾಯಿಕ ನೀಲಿ ಕ್ವಾರ್ಟ್ಜ್ ಹೂದಾನಿ, ಪರ್ಷಿಯನ್ ಹೂವಿನ ವಿನ್ಯಾಸಗಳೊಂದಿಗೆ ಕೈಯಿಂದ ತಯಾರಿಸಲಾಗಿದೆ."),
                "ml": ("ജയ്‌പൂർ ബ്ലൂ പോട്ടറി ഫ്ലവർ വേസ്", "പരമ്പരാഗത നീല ക്വാർട്സ് പൂപ്പാത്രം, പേർഷ്യൻ പുഷ്പ ചിത്രപ്പണികളോടെ കൈകൊണ്ട് നിർമ്മിച്ചത്.")
            }
        },
        {
            "id": "prod_pochampally_saree",
            "artisan_id": artisan_ramesh.id,
            "category": "Handloom",
            "price": 6800.0,
            "cost_price": 3400.0,
            "stock_quantity": 3,
            "primary_image_url": "https://images.unsplash.com/photo-1610030469983-98e550d6193c?auto=format&fit=crop&w=600&q=80",
            "translations": {
                "en": ("Pochampally Ikat Pure Silk Saree", "GI-tagged double-ikat handloom silk saree featuring geometric chevron patterns with natural mulberry silk yarn."),
                "hi": ("पोचमपल्ली इकत शुद्ध रेशम साड़ी", "जीआई-टैग युक्त डबल इकत हथकरघा सिल्क साड़ी, ज्यामितीय आकृतियों और प्राकृतिक मलबरी सिल्क धागों से निर्मित।"),
                "ta": ("போச்சம்பள்ளி இக்கத் பட்டு சேலை", "பாரம்பரிய இரட்டை இக்கத் கைத்தறி பட்டு சேலை, இயற்கை பட்டு நூலால் நெய்யப்பட்டது."),
                "te": ("పోచంపల్లి ఇక్కత్ స్వచ్ఛమైన పట్టు చీర", "జీఐ గుర్తింపు పొందిన డబుల్ ఇక్కత్ మగ్గం పట్టు చీర, ఆకర్షణీయమైన జ్యామితీయ నమూనాలు."),
                "kn": ("ಪೋಚಂಪಲ್ಲಿ ಇಕ್ಕತ್ ಶುದ್ಧ ರೇಷ್ಮೆ ಸೀರೆ", "ಜಿಐ ಟ್ಯಾಗ್ ಪಡೆದ ಡಬಲ್ ಇಕ್ಕತ್ ಕೈಮಗ್ಗ ರೇಷ್ಮೆ ಸೀರೆ, ಜ್ಯಾಮಿತೀಯ ವಿನ್ಯಾಸಗಳೊಂದಿಗೆ."),
                "ml": ("പോച്ചമ്പള്ളി ഇക്കത്ത് ശുദ്ധ പട്ട് സാരി", "ഭൗമസൂചിക പദവിയുള്ള ഡബിൾ ഇക്കത്ത് കൈത്തറി പട്ടുസാരി, ജ്യാമിതീയ പാറ്റേണുകൾ.")
            }
        },
        {
            "id": "prod_channapatna_toy_horse",
            "artisan_id": artisan_ramesh.id,
            "category": "Wood Craft",
            "price": 850.0,
            "cost_price": 310.0,
            "stock_quantity": 12,
            "primary_image_url": "https://images.unsplash.com/photo-1596461404969-9ae70f2830c1?auto=format&fit=crop&w=600&q=80",
            "translations": {
                "en": ("Channapatna Wooden Rocking Horse", "Ivory wood turned toy finished with non-toxic organic vegetable dyes and natural shellac lacquer. Safe for children."),
                "hi": ("चन्नापटना लकड़ी का खिलौना घोड़ा", "आइवरी लकड़ी पर प्राकृतिक वनस्पति रंगों और लाख की पॉलिश से बना पारंपरिक खिलौना। बच्चों के लिए पूर्ण सुरक्षित।"),
                "ta": ("சன்னபட்னா மரக் குதிரை பொம்மை", "இயற்கை காய்கறி வண்ணங்கள் மற்றும் அரக்கு பூசப்பட்ட பாதுகாப்பான பாரம்பரிய மர பொம்மை."),
                "te": ("చెన్నపట్న చెక్క గుర్రం బొమ్మ", "సహజ కూరగాయల రంగులతో మరియు లక్కతో తయారైన విషరహిత చెక్క బొమ్మ."),
                "kn": ("ಚನ್ನಪಟ್ಟಣ ಮರದ ಆಟಿಕೆ ಕುದುರೆ", "ನೈಸರ್ಗಿಕ ತರಕಾರಿ ಬಣ್ಣ ಮತ್ತು ಅರಗಿನಿಂದ ಹೊಳಪು ಮಾಡಿದ ಸಾಂಪ್ರದಾಯಿಕ ಮರದ ಆಟಿಕೆ."),
                "ml": ("ചന്നപട്ടണ തടി കുതിര കളിപ്പാട്ടം", "വിഷരഹിത പ്രകൃതിദത്ത ചായങ്ങളും ലാക്കും ഉപയോഗിച്ച് നിർമ്മിച്ച സുരക്ഷിതമായ തടി കളിപ്പാട്ടം.")
            }
        },
        {
            "id": "prod_kutch_embroidered_clutch",
            "artisan_id": artisan_ramesh.id,
            "category": "Handloom",
            "price": 1250.0,
            "cost_price": 480.0,
            "stock_quantity": 8,
            "primary_image_url": "https://images.unsplash.com/photo-1544816155-12df9643f363?auto=format&fit=crop&w=600&q=80",
            "translations": {
                "en": ("Kutch Hand-Embroidered Mirror Clutch", "Handmade cotton clutch with dense Ahir mirror-work embroidery and colorful silk tassel accents."),
                "hi": ("कच्छ हस्त-कढ़ाई दर्पण क्लच बैग", "घनी अहीर दर्पण-कढ़ाई और रंगीन रेशमी फुंदनों से सजा हस्तनिर्मित सूती क्लच बैग।"),
                "ta": ("கட்ச் கண்ணாடி வேலைப்பாடு கைப்பை", "அஹிர் கண்ணாடி பூத்தையல் வேலைப்பாட்டுடன் கூடிய அழகான கைவினைப் பை."),
                "te": ("కచ్ అద్దాల ఎంబ్రాయిడరీ క్లచ్ బ్యాగ్", "అహిర్ అద్దాల కుట్టుపని మరియు పట్టు కుచ్చులతో చేతితో చేసిన క్లచ్ పర్స్."),
                "kn": ("ಕಚ್ ಕನ್ನಡಿ ಕಸೂತಿ ಕೈಚೀಲ", "ಸಾಂಪ್ರದಾಯಿಕ ಕನ್ನಡಿ ಕಸೂತಿ ಮತ್ತು ರೇಷ್ಮೆ ಕುಚ್ಚುಗಳೊಂದಿಗೆ ಸಿದ್ಧಪಡಿಸಿದ ಹತ್ತಿ ಚೀಲ."),
                "ml": ("കച്ച് കണ്ണാടി തുന്നൽ ക്ലച്ച് ബാഗ്", "പരമ്പരാഗത അഹിർ കണ്ണാടി തുന്നൽ പണികളാൽ അലങ്കരിച്ച കൈത്തറി ക്ലച്ച് ബാഗ്.")
            }
        },
        {
            "id": "prod_terracotta_surahi",
            "artisan_id": artisan_ananya.id,
            "category": "Pottery",
            "price": 620.0,
            "cost_price": 220.0,
            "stock_quantity": 15,
            "primary_image_url": "https://images.unsplash.com/photo-1565193566173-7a0ee3dbe261?auto=format&fit=crop&w=600&q=80",
            "translations": {
                "en": ("Terracotta Long-Neck Surahi", "Natural earthen cooling water pitcher shaped on traditional potter's wheel with etched tribal band motifs."),
                "hi": ("टेराकोटा लंबी गर्दन वाली सुराही", "कुम्हार के चाक पर बनी प्राकृतिक मिट्टी की सुराही, पानी को स्वाभाविक रूप से ठंडा रखती है।"),
                "ta": ("சுடுமண் கூஜா (சுராஹி)", "மண்பாண்ட சக்கரத்தால் சுழற்றப்பட்ட இயற்கை சுடுமண் தண்ணீர் கூஜா, இயற்கையான குளிர்ச்சி."),
                "te": ("టెర్రకోట మట్టి సురాహీ", "సాంప్రదాయ కుమ్మరి చక్రంపై చేసిన సహజ మట్టి నీటి కూజా, సహజ చల్లదనం అందిస్తుంది."),
                "kn": ("ಟೆರಾಕೋಟಾ ಮಣ್ಣಿನ ಸುರಾಯಿ", "ಸಾಂಪ್ರದಾಯಿಕ ಚಕ್ರದ ಮೇಲೆ ಕೈಯಿಂದ ಮಾಡಿದ ಮಣ್ಣಿನ ನೀರಿನ ಪಾತ್ರೆ, ತಂಪಾದ ನೀರು ನೀಡುತ್ತದೆ."),
                "ml": ("ടെറാക്കോട്ട നീണ്ട കഴുത്തുള്ള സുരാഹി", "പരമ്പരാഗത കളിമൺ ചക്രത്തിൽ തീർത്ത ശുദ്ധമായ മൺപാത്രം, സ്വാഭാവിക തണുപ്പ് നൽകുന്നു.")
            }
        },
        {
            "id": "prod_aranmula_mirror",
            "artisan_id": artisan_ananya.id,
            "category": "Metal Craft",
            "price": 9500.0,
            "cost_price": 5100.0,
            "stock_quantity": 2,
            "primary_image_url": "https://images.unsplash.com/photo-1513519245088-0e12902e5a38?auto=format&fit=crop&w=600&q=80",
            "translations": {
                "en": ("Aranmula Metal Alloy Mirror", "Rare front-reflecting metal mirror handcrafted with copper and tin alloy, mounted in carved brass frame."),
                "hi": ("आरणमुला धातु मिश्रधातु दर्पण", "तांबे और टिन की गुप्त मिश्रधातु से बना दुर्लभ फ्रंट-रिफ्लेक्टिंग धातु दर्पण, पीतल के नक्काशीदार फ्रेम में।"),
                "ta": ("ஆரன்முளா உலோகக் கண்ணாடி", "தாமிரம் மற்றும் வெள்ளீயக் கலவையால் செய்யப்பட்ட அரிய வகை முன்னொளிர்வு உலோகக் கண்ணாடி."),
                "te": ("ఆరన్ములా లోహ అద్దం", "రాగి మరియు తగరం మిశ్రమంతో చేతితో పాలిష్ చేసిన అరుదైన సాంప్రదాయ లోహ అద్దం."),
                "kn": ("ಆರನ್ಮುಳ ಲೋಹದ ಕನ್ನಡಿ", "ತಾಮ್ರ ಮತ್ತು ತವರದ ಮಿಶ್ರಲೋಹದಿಂದ ತಯಾರಿಸಿದ ಅಪರೂಪದ ಮುಂಭಾಗ ಪ್ರತಿಫಲಿಸುವ ಕನ್ನಡಿ."),
                "ml": ("ആറന്മുള വാൽക്കണ്ണാടി", "ചെമ്പും വെളുത്തീയവും ചേർത്ത അത്യപൂർവ്വ ലോഹക്കണ്ണാടി, പിച്ചള ചട്ടക്കൂടിൽ തീർത്തത്.")
            }
        },
        {
            "id": "prod_tanjore_painting",
            "artisan_id": artisan_ramesh.id,
            "category": "Painting",
            "price": 14200.0,
            "cost_price": 7500.0,
            "stock_quantity": 2,
            "primary_image_url": "https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?auto=format&fit=crop&w=600&q=80",
            "translations": {
                "en": ("Tanjore 22K Gold Foil Painting", "Classic Thanjavur relief painting on seasoned teakwood board with authentic 22K gold foil and Jaipur gemstones."),
                "hi": ("तंजौर 22 कैरेट स्वर्ण पत्र पेंटिंग", "सागौन की लकड़ी पर 22 कैरेट असली सोने के वर्क और जयपुर पत्थरों से अलंकृत शास्त्रीय तंजौर पेंटिंग।"),
                "ta": ("தஞ்சாவூர் 22K தங்கத் தட்டு ஓவியம்", "தேக்கு மரப் பலகையில் 22 காரட் அசல் தங்க இலை மற்றும் மணிகளால் செதுக்கப்பட்ட பாரம்பரிய ஓவியம்."),
                "te": ("తంజావూరు 22K బంగారు తాపడం పెయింటింగ్", "టేకు చెక్కపై 22 క్యారెట్ల స్వచ్ఛమైన బంగారు రేకు మరియు రత్నాలతో రూపొందించిన కళాఖండం."),
                "kn": ("ತಂಜಾವೂರು 22K ಚಿನ್ನದ ಹಾಳೆ ಚಿತ್ರಕಲೆ", "ತೇಗದ ಹಲಗೆಯ ಮೇಲೆ 22 ಕ್ಯಾರೆಟ್ ಚಿನ್ನದ ಹಾಳೆ ಮತ್ತು ರತ್ನಗಳಿಂದ ರಚಿಸಲಾದ ಶಾಸ್ತ್ರೀಯ ಕಲಾಕೃತಿ."),
                "ml": ("തഞ്ചാവൂർ 22K സ്വർണ്ണ ചിത്രകല", "തേക്ക് തടിയിൽ 22 കാരറ്റ് സ്വർണ്ണത്തകിടും രത്നങ്ങളും പതിപ്പിച്ച ക്ലാസിക് തഞ്ചാവൂർ ചിത്രം.")
            }
        },
        {
            "id": "prod_dhokra_tribal_figurine",
            "artisan_id": artisan_ananya.id,
            "category": "Metal Craft",
            "price": 2800.0,
            "cost_price": 1150.0,
            "stock_quantity": 6,
            "primary_image_url": "https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=600&q=80",
            "translations": {
                "en": ("Bastar Dhokra Lost-Wax Figurine", "4000-year-old lost-wax bell metal casting representing indigenous tribal musicians of Bastar."),
                "hi": ("बस्तर ढोकरा लॉस्ट-वैक्स धातु मूर्ति", "चार हजार वर्ष पुरानी मोम ढलाई तकनीक से बनी बस्तर के आदिवासी संगीतकारों की कांस्य धातु मूर्ति।"),
                "ta": ("பஸ்தார் தோக்ரா மெழுகு வார்ப்பு சிலை", "4000 ஆண்டுகள் பழமையான மெழுகு வார்ப்பு முறையால் செய்யப்பட்ட பாரம்பரிய பழங்குடி வெண்கலச் சிலை."),
                "te": ("బస్తర్ ధోక్రా గిరిజన విగ్రహం", "నాలుగు వేల సంవత్సరాల పురాతన లాస్ట్-వాక్స్ పద్ధతిలో రూపొందించిన ఇత్తడి గిరిజన కళారూపం."),
                "kn": ("ಬಸ್ತಾರ್ ಧೋಕ್ರಾ ಮೇಣದ ಎರಕಹೊಯ್ದ ಶಿಲ್ಪ", "ಪುರಾತನ ಲಾಸ್ಟ್-ವ್ಯಾಕ್ಸ್ ತಂತ್ರಜ್ಞಾನದಲ್ಲಿ ತಯಾರಿಸಿದ ಗಿರಿಜನ ಕಲಾವಿದರ ಕಂಚಿನ ಶಿಲ್ಪ."),
                "ml": ("ബസ്തർ ധോക്ര ലോസ്റ്റ്-വാക്സ് ശില്പം", "നാലായിരം വർഷം പഴക്കമുള്ള മെഴുക് വാർപ്പുവിദ്യയിൽ തീർത്ത പരമ്പരാഗത വെങ്കല ശിൽപം.")
            }
        },
        {
            "id": "prod_madhubani_stole",
            "artisan_id": artisan_ramesh.id,
            "category": "Handloom",
            "price": 2100.0,
            "cost_price": 820.0,
            "stock_quantity": 7,
            "primary_image_url": "https://images.unsplash.com/photo-1607344645866-009c320c5ab8?auto=format&fit=crop&w=600&q=80",
            "translations": {
                "en": ("Madhubani Hand-Painted Tussar Stole", "Pure tussar silk stole hand-painted with bamboo nibs depicting Tree of Life and fish harmony motifs."),
                "hi": ("मधुबनी हस्त-चित्रित टसर सिल्क स्टोल", "बांस की कलम से शुद्ध टसर सिल्क पर उकेरा गया 'जीवन वृक्ष' और मत्स्य रूपांकनों वाला सुंदर स्टोल।"),
                "ta": ("மதுபானி கைவண்ண பட்டு சால்வை", "மூங்கில் பேனாவால் தூய தசார் பட்டில் வரையப்பட்ட பாரம்பரிய மதுபானி ஓவிய சால்வை."),
                "te": ("మధుబని చేతితో వేసిన సిల్క్ స్టోల్", "వెదురు కలంతో స్వచ్ఛమైన టస్సార్ పట్టుపై జీవ వృక్ష నమూనాలతో వేసిన చిత్రకళా శాలువా."),
                "kn": ("ಮಧುಬನಿ ಕೈಯಿಂದ ಚಿತ್ರಿಸಿದ ರೇಷ್ಮೆ ಶಾಲು", "ಬಿದಿರಿನ ಲೇಖನಿಯಿಂದ ಶುದ್ಧ ಟಸ್ಸಾರ್ ರೇಷ್ಮೆಯ ಮೇಲೆ ಚಿತ್ರಿಸಿದ ಸಾಂಪ್ರದಾಯಿಕ ಮಧುಬನಿ ಶಾಲು."),
                "ml": ("മധുബനി കൈകൊണ്ട് വരച്ച സിൽക്ക് സ്റ്റോൾ", "മുളങ്കോലുകൊണ്ട് ശുദ്ധമായ ടസ്സർ പട്ടിൽ ജീവവൃക്ഷം വരച്ച മനോഹരമായ ഷാൾ.")
            }
        },
        {
            "id": "prod_rosewood_spice_box",
            "artisan_id": artisan_ramesh.id,
            "category": "Wood Craft",
            "price": 1850.0,
            "cost_price": 720.0,
            "stock_quantity": 9,
            "primary_image_url": "https://images.unsplash.com/photo-1590736969955-71cc94801759?auto=format&fit=crop&w=600&q=80",
            "translations": {
                "en": ("Saharanpur Carved Sheesham Spice Box", "Hand-carved Indian rosewood masala dabba with 7 removable bowls and brass latch closure."),
                "hi": ("सहारनपुर नक्काशीदार शीशम मसाला दानी", "हाथ की नक्काशी वाली शीशम की लकड़ी की मसाला दानी, 7 कटोरियों और पीतल की कुंडी के साथ।"),
                "ta": ("சஹாரன்பூர் ரோஸ்வுட் மசாலா பெட்டி", "கைவேலைப்பாடு செய்யப்பட்ட ஈட்டி மரத்தாலான 7 கிண்ணங்கள் கொண்ட பாரம்பரிய மசாலா பெட்டி."),
                "te": ("సహారన్‌పూర్ చెక్కిన రోజ్‌వుడ్ మసాలా పెట్టె", "చేతితో చెక్కిన ఇనుప చెక్క మసాలా డబ్బా, 7 గిన్నెలు మరియు ఇత్తడి తాళంతో."),
                "kn": ("ಸಹಾರನ್‌ಪುರ ಕೆತ್ತನೆಯ ಶ್ರೀಗಂಧ/ಸೀಸಮ್ ಮಸಾಲೆ ಪೆಟ್ಟಿಗೆ", "ಕೈಕೆತ್ತನೆಯ ಸೀಸಮ್ ಮರದ ಸಾಂಪ್ರದಾಯಿಕ ಮಸಾಲೆ ಪೆಟ್ಟಿಗೆ, 7 ಪಾತ್ರೆಗಳೊಂದಿಗೆ."),
                "ml": ("സഹാറൻപൂർ റോസ്‌വുഡ് മസാല പെട്ടി", "കൈകൊണ്ട് കൊത്തുപണി ചെയ്ത ഈട്ടിത്തടി മസാല പെട്ടി, പിച്ചള താഴുപയോഗിച്ചുള്ളത്.")
            }
        },
        {
            "id": "prod_assam_bamboo_basket",
            "artisan_id": artisan_ananya.id,
            "category": "Bamboo",
            "price": 540.0,
            "cost_price": 190.0,
            "stock_quantity": 20,
            "primary_image_url": "https://images.unsplash.com/photo-1584917865442-de89df76afd3?auto=format&fit=crop&w=600&q=80",
            "translations": {
                "en": ("Assam Handwoven Golden Bamboo Basket", "Finely split natural golden cane basket woven by master artisans of Barak Valley for fruit and craft storage."),
                "hi": ("असम हस्तनिर्मित सुनहरा बांस की टोकरी", "बराक घाटी के कारीगरों द्वारा बारीक प्राकृतिक बांस की तीलियों से बुनी गई टिकाऊ टोकरी।"),
                "ta": ("அசாம் கைவினை மூங்கில் கூடை", "இயற்கையான பொன்னிற மூங்கில் இழைகளால் பின்னப்பட்ட நேர்த்தியான பலபயன் கூடை."),
                "te": ("అస్సాం చేనేత వెదురు బుట్ట", "బరాక్ లోయ కళాకారులచే సున్నితమైన వెదురుతో అల్లిన అందమైన పండ్ల బుట్ట."),
                "kn": ("ಅಸ್ಸಾಂ ಕೈಯಿಂದ ಹೆಣೆದ ಬಿದಿರಿನ ಬುಟ್ಟಿ", "ನೈಸರ್ಗಿಕ ಬಿದಿರಿನ ಪಟ್ಟಿಗಳಿಂದ ಹೆಣೆದ ಸುಂದರ ಮತ್ತು ಗಟ್ಟಿಯಾದ ಕರಕುಶಲ ಬುಟ್ಟಿ."),
                "ml": ("അസം കൈത്തറി മുള കൊട്ട", "സ്വാഭാവിക മുളച്ചീളുകളാൽ നെയ്തെടുത്ത സുന്ദരവും ദൃഢവുമായ അസം മുളക്കൊട്ട.")
            }
        },
        {
            "id": "prod_bidriware_plate",
            "artisan_id": artisan_ananya.id,
            "category": "Metal Craft",
            "price": 3800.0,
            "cost_price": 1700.0,
            "stock_quantity": 4,
            "primary_image_url": "https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?auto=format&fit=crop&w=600&q=80",
            "translations": {
                "en": ("Bidriware Pure Silver Inlay Plate", "Zinc-copper alloy decorative plate blackened with Bidar fort soil and inlaid with 99.9% fine silver wire."),
                "hi": ("बिदरीवेयर शुद्ध चांदी की नक्काशीदार थाली", "बीदर मिट्टी से काली की गई जस्ता-तांबा मिश्रधातु थाली, जिस पर शुद्ध चांदी के तारों की बारीक जड़ाई है।"),
                "ta": ("பித்ரிவேர் வெள்ளி வேலைப்பாடு தட்டு", "தூய வெள்ளி கம்பிகளால் செதுக்கப்பட்ட பாரம்பரிய பிதர் கருப்பு உலோக அலங்காரத் தட்டு."),
                "te": ("బిద్రివేర్ స్వచ్ఛమైన వెండి తాపడం ప్లేట్", "బీదర్ కోట మట్టితో నల్లబరిచిన జింక్-రాగి మిశ్రమంపై వెండి తీగలతో జరిపిన సూక్ష్మ కళ."),
                "kn": ("ಬಿದ್ರಿವೇರ್ ಶುದ್ಧ ಬೆಳ್ಳಿ ಕೆತ್ತನೆಯ ತಟ್ಟೆ", "ಬೀದರ್ ಮಣ್ಣಿನಿಂದ ಕಪ್ಪಾಗಿಸಿದ ಮಿಶ್ರಲೋಹದ ಮೇಲೆ ಶುದ್ಧ ಬೆಳ್ಳಿಯ ತಂತಿಗಳಿಂದ ಮಾಡಿದ ಜಡಾವಣೆ ಕಲೆ."),
                "ml": ("ബിദ്രിക്രാഫ്റ്റ് വെള്ളി പതിപ്പിച്ച അലങ്കാര പ്ലേറ്റ്", "ബിദാർ മണ്ണിൽ കറുപ്പിച്ച ലോഹത്തിൽ ശുദ്ധമായ വെള്ളിനൂലുകൾ പതിപ്പിച്ച പ്ലേറ്റ്.")
            }
        }
    ]

    for p_info in products_data:
        prod = Product(
            id=p_info["id"],
            artisan_id=p_info["artisan_id"],
            category=p_info["category"],
            price=p_info["price"],
            cost_price=p_info["cost_price"],
            stock_quantity=p_info["stock_quantity"],
            primary_image_url=p_info["primary_image_url"],
            status="active"
        )
        db.add(prod)
        db.flush()

        for lang, (title, desc) in p_info["translations"].items():
            trans = ProductTranslation(
                product_id=prod.id,
                language_code=lang,
                title=title,
                description=desc,
                tags=f"craft,{p_info['category'].lower()},{lang}",
                materials=p_info["category"]
            )
            db.add(trans)

    db.commit()

    print("Seeding demo orders...")
    # Demo Order 1
    order1 = Order(
        id="ord_demo_101",
        artisan_id=artisan_ananya.id,
        customer_name="Pooja Venkat",
        customer_phone="9840123456",
        customer_address="Flat 4B, Lotus Apartments, Indiranagar, Bengaluru, 560038",
        total_amount=2900.0,
        status="confirmed",
    )
    db.add(order1)
    db.flush()
    item1 = OrderItem(
        id="ord_item_101_1",
        order_id=order1.id,
        product_id="prod_blue_pottery_vase",
        quantity=2,
        unit_price=1450.0,
    )
    db.add(item1)

    # Demo Order 2
    order2 = Order(
        id="ord_demo_102",
        artisan_id=artisan_ramesh.id,
        customer_name="Vikramaditya Roy",
        customer_phone="9830987654",
        customer_address="12/1 Gariahat Road, Kolkata, West Bengal, 700019",
        total_amount=6800.0,
        status="shipped",
    )
    db.add(order2)
    db.flush()
    item2 = OrderItem(
        id="ord_item_102_1",
        order_id=order2.id,
        product_id="prod_pochampally_saree",
        quantity=1,
        unit_price=6800.0,
    )
    db.add(item2)

    db.commit()
    db.close()
    print("Seed complete! 2 artisans, 12 products (with 6 languages each), and 2 orders seeded.")

if __name__ == "__main__":
    seed()
