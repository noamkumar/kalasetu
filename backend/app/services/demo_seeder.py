import logging
import uuid
from datetime import datetime, timezone, timedelta
from sqlalchemy.orm import Session

from app.models.db_models import Artisan, Product, ProductTranslation, Order, OrderItem
from app.db.session import SessionLocal

logger = logging.getLogger("kalasetu.demo_seeder")

DEMO_ACCOUNTS = [
    {
        "id": "demo-artisan-rameshwar-01",
        "phone": "+919876543210",
        "name": "Rameshwar Prajapati",
        "role": "artisan",
        "craft_type": "Pottery",
        "cluster_location": "Gorakhpur Terracotta Cluster",
        "state": "Uttar Pradesh",
        "experience_years": 22,
        "pehchan_id": "UP-POT-2024-8841",
        "preferred_language": "hi",
    },
    {
        "id": "demo-artisan-meenakshi-02",
        "phone": "+919876543211",
        "name": "Devi Meenakshi",
        "role": "artisan",
        "craft_type": "Handloom",
        "cluster_location": "Kanchipuram Silk Weaving Cluster",
        "state": "Tamil Nadu",
        "experience_years": 18,
        "pehchan_id": "TN-HDL-2023-1029",
        "preferred_language": "ta",
    },
    {
        "id": "demo-artisan-somnath-03",
        "phone": "+919876543212",
        "name": "Somnath Soren",
        "role": "artisan",
        "craft_type": "Wood Craft",
        "cluster_location": "Bankura Tribal Craft Centre",
        "state": "West Bengal",
        "experience_years": 15,
        "pehchan_id": "WB-WOD-2022-5501",
        "preferred_language": "en",
    },
    {
        "id": "demo-buyer-priya-01",
        "phone": "+919876543220",
        "name": "Priya Sharma",
        "role": "buyer",
        "craft_type": "Customer",
        "cluster_location": "Connaught Place",
        "state": "Delhi",
        "experience_years": None,
        "pehchan_id": None,
        "preferred_language": "en",
    },
    {
        "id": "demo-buyer-vikram-02",
        "phone": "+919876543221",
        "name": "Vikram Singhania",
        "role": "buyer",
        "craft_type": "Customer",
        "cluster_location": "Indiranagar",
        "state": "Karnataka",
        "experience_years": None,
        "pehchan_id": None,
        "preferred_language": "kn",
    },
]

DEMO_PRODUCTS = [
    {
        "id": "prod-demo-terracotta-pitcher-01",
        "artisan_id": "demo-artisan-rameshwar-01",
        "category": "Pottery",
        "price": 599.0,
        "cost_price": 380.0,
        "status": "live",
        "stock_quantity": 8,
        "primary_image_url": "/static/uploads/demo_pitcher.jpg",
        "enhanced_image_url": "/static/uploads/demo_pitcher.jpg",
        "translations": {
            "en": {
                "title": "Handcrafted Terracotta Water Pitcher",
                "description": "Natural red clay pitcher handcrafted on traditional potter's wheel with porous earthen cooling properties.",
                "materials": "100% Natural River Clay",
                "care_instructions": "Rinse with water before first use. Avoid chemical soap.",
                "tags": "pottery, terracotta, handmade, earthen, eco-friendly"
            },
            "hi": {
                "title": "हस्तनिर्मित मिट्टी का जल पात्र (सुराही)",
                "description": "पारंपरिक चाक पर शुद्ध लाल मिट्टी से निर्मित जल पात्र, जो पानी को स्वाभाविक रूप से शीतल रखता है।",
                "materials": "100% प्राकृतिक नदी की मिट्टी",
                "care_instructions": "उपयोग से पहले सादे पानी से धोएं। साबुन का उपयोग न करें।",
                "tags": "मिट्टी, बर्तन, हस्तशिल्प, पर्यावरण-अनुकूल"
            },
            "ta": {
                "title": "கைவினை சுடுமண் தண்ணீர் கூஜா",
                "description": "இயற்கையான சிவப்பு களிமண்ணில் கைவினைஞரால் செய்யப்பட்ட பாரம்பரிய தண்ணீர் பானை.",
                "materials": "100% தூய இயற்கை களிமண்",
                "care_instructions": "முதல் பயன்பாட்டிற்கு முன் தண்ணீரில் கழுவவும்.",
                "tags": "சுடுமண், மண்பாண்டம், கைவினை"
            },
            "te": {
                "title": "చేతితో చేసిన టెర్రకోట నీటి కూజా",
                "description": "సహజమైన ఎర్ర మట్టితో సంప్రదాయ కుమ్మరి చక్రంపై తయారు చేసిన సహజ శీతలీకరణ నీటి పాత్ర.",
                "materials": "100% సహజ నది మట్టి",
                "care_instructions": "మొదటి సారి వాడే ముందు నీటితో కడగాలి.",
                "tags": "మట్టిపాత్రలు, చేతిపని, సహజం"
            },
            "kn": {
                "title": "ಕೈಯಿಂದ ಮಾಡಿದ ಜೇಡಿಮಣ್ಣಿನ ನೀರಿನ ಕೊಡ",
                "description": "ನೈಸರ್ಗಿಕ ಕೆಂಪು ಮಣ್ಣಿನಿಂದ ಕುಂಬಾರ ಚಕ್ರದಲ್ಲಿ ತಯಾರಿಸಿದ ಸಾಂಪ್ರದಾಯಿಕ ನೀರಿನ ಪಾತ್ರೆ.",
                "materials": "100% ನೈಸರ್ಗಿಕ ಜೇಡಿಮಣ್ಣು",
                "care_instructions": "ಬಳಕೆಗೆ ಮುನ್ನ ನೀರಿನಿಂದ ತೊಳೆಯಿರಿ.",
                "tags": "ಮಣ್ಣಿನ ಪಾತ್ರೆ, ಕರಕುಶಲ, ಪರಿಸರ ಸ್ನೇಹಿ"
            },
            "ml": {
                "title": "കൈകൊണ്ട് നിർമ്മിച്ച മൺ കൂജ",
                "description": "സ്വാഭാവിക തണുപ്പ് നൽകുന്ന പരമ്പരാഗത ചുവന്ന മണ്ണിൽ തീർത്ത മൺപാത്രം.",
                "materials": "100% പ്രകൃതിദത്ത മണ്ണ്",
                "care_instructions": "ഉപയോഗിക്കുന്നതിന് മുമ്പ് വെറും വെള്ളത്തിൽ കഴുകുക.",
                "tags": "മൺപാത്രം, കരകൗശലം, പ്രകൃതിദത്തം"
            }
        }
    },
    {
        "id": "prod-demo-silk-stole-02",
        "artisan_id": "demo-artisan-meenakshi-02",
        "category": "Handloom",
        "price": 2499.0,
        "cost_price": 1650.0,
        "status": "live",
        "stock_quantity": 4,
        "primary_image_url": "/static/uploads/demo_silk.jpg",
        "enhanced_image_url": "/static/uploads/demo_silk.jpg",
        "translations": {
            "en": {
                "title": "Pure Mulberry Silk Zari Stole",
                "description": "Woven on pit loom with authentic gold zari border, representing centuries of Tamil temple weaving heritage.",
                "materials": "Pure Mulberry Silk, Gold-plated Zari",
                "care_instructions": "Dry clean only. Store in muslin cloth.",
                "tags": "handloom, silk, kanchipuram, heritage, zari"
            },
            "hi": {
                "title": "शुद्ध शहतूत रेशम ज़री स्टोल",
                "description": "कांचीपुरम की ऐतिहासिक बुनाई कला से प्रेरित पारंपरिक सोने की ज़री वाला हस्तनिर्मित सिल्क स्टोल।",
                "materials": "शुद्ध रेशम, ज़री",
                "care_instructions": "केवल ड्राई क्लीन करें।",
                "tags": "हथकरघा, रेशम, पारंपरिक, जरी"
            },
            "ta": {
                "title": "தூய மல்பெரி பட்டு ஜரிகை சால்வை",
                "description": "காஞ்சிபுரத்து பாரம்பரிய தறியில் நெய்யப்பட்ட தங்க ஜரிகை கொண்ட பட்டு சால்வை.",
                "materials": "தூய பட்டு, தங்க ஜரிகை",
                "care_instructions": "உலர் சலவை மட்டுமே.",
                "tags": "கைத்தறி, பட்டு, காஞ்சிபுரம், ஜரிகை"
            },
            "te": {
                "title": "స్వచ్ఛమైన మల్బరీ పట్టు జరీ స్టోల్",
                "description": "సంప్రదాయ పిట్ మగ్గంపై బంగారు జరీ అంచుతో నేసిన స్వచ్ఛమైన పట్టు శాలువా.",
                "materials": "స్వచ్ఛమైన పట్టు, జరీ",
                "care_instructions": "డ్రై క్లీన్ మాత్రమే చేయాలి.",
                "tags": "చేనేత, పట్టు, జరీ, సంప్రదాయం"
            },
            "kn": {
                "title": "ಶುದ್ಧ ಹಿಪ್ಪುನೇರಳೆ ರೇಷ್ಮೆ ಜರಿ ಶಾಲು",
                "description": "ಚಿನ್ನದ ಜರಿ ಅಂಚಿನೊಂದಿಗೆ ಸಾಂಪ್ರದಾಯಿಕ ಮಗ್ಗದಲ್ಲಿ ನೇಯ್ದ ನೈಜ ರೇಷ್ಮೆ ಶಾಲು.",
                "materials": "ಶುದ್ಧ ರೇಷ್ಮೆ, ಜರಿ",
                "care_instructions": "ಡ್ರೈ ಕ್ಲೀನ್ ಮಾತ್ರ.",
                "tags": "ಕೈಮಗ್ಗ, ರೇಷ್ಮೆ, ಜರಿ, ಸಾಂಪ್ರದಾಯಿಕ"
            },
            "ml": {
                "title": "ശുദ്ധമായ പട്ടു ജരി ഷാൾ",
                "description": "സ്വർണ്ണ ജരി ബോർഡറോടെ പരമ്പരാഗത തറിയിൽ നെയ്തെടുത്ത പട്ടു ഷാൾ.",
                "materials": "ശുദ്ധമായ പട്ട്, ജരി",
                "care_instructions": "ഡ്രൈ ക്ലീൻ മാത്രം ചെയ്യുക.",
                "tags": "കൈത്തറി, പട്ട്, പരമ്പരാഗതം"
            }
        }
    },
    {
        "id": "prod-demo-wood-platter-03",
        "artisan_id": "demo-artisan-somnath-03",
        "category": "Wood Craft",
        "price": 1299.0,
        "cost_price": 850.0,
        "status": "live",
        "stock_quantity": 6,
        "primary_image_url": "/static/uploads/demo_wood.jpg",
        "enhanced_image_url": "/static/uploads/demo_wood.jpg",
        "translations": {
            "en": {
                "title": "Hand-Carved Teakwood Platter",
                "description": "Reclaimed seasoned teakwood serving platter with tribal geometric engraving and beeswax organic finish.",
                "materials": "Seasoned Teakwood, Natural Beeswax",
                "care_instructions": "Wipe with damp cloth. Reapply coconut oil occasionally.",
                "tags": "woodcraft, teakwood, tribal, artisan, handmade"
            },
            "hi": {
                "title": "हस्तनिर्मित सागौन की लकड़ी का थाल",
                "description": "प्राकृतिक मोम की फिनिशिंग और जनजातीय नक्काशी के साथ टिकाऊ सागौन की लकड़ी से निर्मित थाल।",
                "materials": "सागौन की लकड़ी, प्राकृतिक मोम",
                "care_instructions": "गीले कपड़े से पोंछें।",
                "tags": "काष्ठकला, हस्तशिल्प, लकड़ी"
            },
            "ta": {
                "title": "கைவினை தேக்கு மர தட்டு",
                "description": "பாரம்பரிய கைவேலைப்பாடுகளுடன் செதுக்கப்பட்ட தேக்கு மர உணவு தட்டு.",
                "materials": "தேக்கு மரம், இயற்கை மெழுகு",
                "care_instructions": "ஈரமான துணியால் துடைக்கவும்.",
                "tags": "மரவேலை, தேக்கு, கைவினை"
            },
            "te": {
                "title": "చేతితో చెక్కిన టేకు చెక్క ప్లేట్",
                "description": "గిరిజన రేఖాగణిత డిజైన్‌తో చెక్కిన మన్నికైన టేకు చెక్క సర్వింగ్ పళ్లెం.",
                "materials": "టేకు చెక్క, సహజ మైనం",
                "care_instructions": "తడి గుడ్డతో తుడవండి.",
                "tags": "చెక్కపని, టేకు, చేతిపని"
            },
            "kn": {
                "title": "ಕೈಯಿಂದ ಕೆತ್ತಿದ ತೇಗದ ಮರದ ತಟ್ಟೆ",
                "description": "ಬುಡಕಟ್ಟು ವಿನ್ಯಾಸಗಳೊಂದಿಗೆ ಕೆತ್ತಲಾದ ನೈಸರ್ಗಿಕ ತೇಗದ ಮರದ ತಟ್ಟೆ.",
                "materials": "ತೇಗದ ಮರ, ನೈಸರ್ಗಿಕ ಮೇಣ",
                "care_instructions": "ತೇವವಾದ ಬಟ್ಟೆಯಿಂದ ಒರೆಸಿ.",
                "tags": "ಮರದ ಕೆತ್ತನೆ, ತೇಗ, ಕರಕುಶಲ"
            },
            "ml": {
                "title": "തേക്ക് തടിയിൽ കൊത്തിയെടുത്ത തളിക",
                "description": "പ്രകൃതിദത്ത മെഴുക് മിനുസപ്പെടുത്തിയ സുസ്ഥിരമായ തേക്ക് തടി തളിക.",
                "materials": "തേക്ക് തടി, പ്രകൃതിദത്ത മെഴുക്",
                "care_instructions": "നനഞ്ഞ തുണികൊണ്ട് തുടയ്ക്കുക.",
                "tags": "തടിപ്പണി, തേക്ക്, കരകൗശലം"
            }
        }
    }
]

def seed_demo_data(db: Session) -> None:
    """Seeds 3 demo artisans, 2 demo buyers, products with 6-language translations, and orders."""
    now = datetime.now(timezone.utc)
    seeded_users = 0
    seeded_prods = 0
    seeded_orders = 0

    # 1. Seed Accounts
    for acc in DEMO_ACCOUNTS:
        existing = db.query(Artisan).filter(Artisan.phone == acc["phone"]).first()
        if not existing:
            artisan = Artisan(
                id=acc["id"],
                phone=acc["phone"],
                name=acc["name"],
                role=acc["role"],
                craft_type=acc["craft_type"],
                cluster_location=acc["cluster_location"],
                state=acc["state"],
                experience_years=acc["experience_years"],
                pehchan_id=acc["pehchan_id"],
                preferred_language=acc["preferred_language"],
                created_at=now,
                updated_at=now,
            )
            db.add(artisan)
            seeded_users += 1

    db.commit()

    # 2. Seed Products
    for p_data in DEMO_PRODUCTS:
        existing_p = db.query(Product).filter(Product.id == p_data["id"]).first()
        if not existing_p:
            prod = Product(
                id=p_data["id"],
                artisan_id=p_data["artisan_id"],
                category=p_data["category"],
                price=p_data["price"],
                cost_price=p_data["cost_price"],
                status=p_data["status"],
                stock_quantity=p_data["stock_quantity"],
                primary_image_url=p_data["primary_image_url"],
                enhanced_image_url=p_data["enhanced_image_url"],
                created_at=now,
                updated_at=now,
            )
            db.add(prod)
            db.flush()

            for lang_code, t_data in p_data["translations"].items():
                trans = ProductTranslation(
                    id=f"{p_data['id']}-{lang_code}",
                    product_id=p_data["id"],
                    language_code=lang_code,
                    title=t_data["title"],
                    description=t_data["description"],
                    materials=t_data["materials"],
                    care_instructions=t_data["care_instructions"],
                    tags=t_data["tags"],
                )
                db.add(trans)
            seeded_prods += 1

    db.commit()

    # 3. Seed Orders
    demo_orders_data = [
        {
            "id": "order-demo-01",
            "artisan_id": "demo-artisan-rameshwar-01",
            "buyer_id": "demo-buyer-priya-01",
            "customer_name": "Priya Sharma",
            "customer_phone": "+919876543220",
            "customer_address": "44, Barakhamba Road, Connaught Place, New Delhi 110001",
            "total_amount": 599.0,
            "status": "pending",
            "payment_method": "cash_on_delivery",
            "items": [("prod-demo-terracotta-pitcher-01", 1, 599.0)]
        },
        {
            "id": "order-demo-02",
            "artisan_id": "demo-artisan-meenakshi-02",
            "buyer_id": "demo-buyer-vikram-02",
            "customer_name": "Vikram Singhania",
            "customer_phone": "+919876543221",
            "customer_address": "812, 12th Main Road, Indiranagar, Bengaluru, Karnataka 560038",
            "total_amount": 2499.0,
            "status": "shipped",
            "payment_method": "upi_prepaid",
            "courier_name": "India Post Speed Post",
            "tracking_id": "IN882947190",
            "items": [("prod-demo-silk-stole-02", 1, 2499.0)]
        },
        {
            "id": "order-demo-03",
            "artisan_id": "demo-artisan-somnath-03",
            "buyer_id": "demo-buyer-priya-01",
            "customer_name": "Priya Sharma",
            "customer_phone": "+919876543220",
            "customer_address": "44, Barakhamba Road, Connaught Place, New Delhi 110001",
            "total_amount": 1299.0,
            "status": "delivered",
            "payment_method": "upi_prepaid",
            "courier_name": "BlueDart Express",
            "tracking_id": "BD771829012",
            "items": [("prod-demo-wood-platter-03", 1, 1299.0)]
        }
    ]

    for o_info in demo_orders_data:
        existing_o = db.query(Order).filter(Order.id == o_info["id"]).first()
        if not existing_o:
            order = Order(
                id=o_info["id"],
                artisan_id=o_info["artisan_id"],
                buyer_id=o_info["buyer_id"],
                customer_name=o_info["customer_name"],
                customer_phone=o_info["customer_phone"],
                customer_address=o_info["customer_address"],
                total_amount=o_info["total_amount"],
                status=o_info["status"],
                payment_method=o_info.get("payment_method", "cash_on_delivery"),
                courier_name=o_info.get("courier_name"),
                tracking_id=o_info.get("tracking_id"),
                created_at=now - timedelta(days=2),
            )
            db.add(order)
            db.flush()

            for p_id, qty, unit_p in o_info["items"]:
                item = OrderItem(
                    id=str(uuid.uuid4()),
                    order_id=o_info["id"],
                    product_id=p_id,
                    quantity=qty,
                    unit_price=unit_p,
                )
                db.add(item)
            seeded_orders += 1

    db.commit()
    logger.info(f"Demo seed complete: {seeded_users} users, {seeded_prods} products, {seeded_orders} orders.")
