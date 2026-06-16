-- Word lists for Pictionary Party.
-- Each category has e=easy, m=medium, h=hard word arrays.
return {
    fr = {
        { id = "animaux",   name = "Animaux", words = {
            e = { "Chat","Chien","Cheval","Lion","Lapin","Vache","Canard","Grenouille","Poisson","Oiseau" },
            m = { "Girafe","Crocodile","Pingouin","Dauphin","Kangourou","Pieuvre","Flamant","Bison","Renard","Hibou" },
            h = { "Ornithorynque","Axolotl","Pangolin","Nautile","Tapir","Tatou","Okapi","Lémur","Varan","Narval" },
        }},
        { id = "metiers",   name = "Métiers", words = {
            e = { "Médecin","Pompier","Policier","Boulanger","Dentiste","Infirmier","Pilote","Facteur","Cuisinier","Professeur" },
            m = { "Architecte","Plombier","Chirurgien","Journaliste","Photographe","Comptable","Géologue","Diplomate","Vétérinaire","Pharmacien" },
            h = { "Astrophysicien","Entomologiste","Paléontologue","Cartographe","Cryptologue","Épidémiologiste","Commissaire","Sophrologie","Marionnettiste","Luthier" },
        }},
        { id = "sports",    name = "Sports", words = {
            e = { "Football","Tennis","Natation","Ski","Boxe","Golf","Rugby","Judo","Vélo","Basket" },
            m = { "Escrime","Aviron","Badminton","Équitation","Plongée","Handball","Biathlon","Curling","Volley","Triathlon" },
            h = { "Bobsleigh","Pentathlon","Pelote basque","Kitesurf","Luge","Crosse","Squash","Skeleton","Sumo","Polo" },
        }},
        { id = "nourriture", name = "Nourriture", words = {
            e = { "Pizza","Gâteau","Pain","Fromage","Soupe","Glace","Salade","Crêpe","Spaghetti","Omelette" },
            m = { "Quiche","Fondue","Ratatouille","Couscous","Risotto","Paella","Meringue","Artichaut","Sushi","Lasagnes" },
            h = { "Bourguignon","Millefeuille","Bouillabaisse","Cassoulet","Profiteroles","Blanquette","Gougères","Croquembouche","Tatin","Vichyssoise" },
        }},
        { id = "lieux",     name = "Lieux", words = {
            e = { "Plage","Montagne","Forêt","Gare","Aéroport","Marché","Église","École","Hôpital","Château" },
            m = { "Désert","Volcan","Phare","Mosquée","Fjord","Monastère","Stade","Bibliothèque","Grotte","Phare" },
            h = { "Catacombes","Atoll","Pagode","Estuaire","Bunker","Labyrinthe","Mégalithe","Citerne","Crypte","Léproserie" },
        }},
        { id = "objets",    name = "Objets", words = {
            e = { "Clé","Chaise","Lampe","Téléphone","Sac","Livre","Horloge","Parapluie","Ballon","Marteau" },
            m = { "Microscope","Télescope","Accordéon","Sablier","Compas","Arrosoir","Balançoire","Ventilateur","Trampoline","Harmonica" },
            h = { "Sextant","Alambic","Trépied","Tire-bouchon","Soufflet","Pluviomètre","Équerre","Décapsuleur","Astrolabe","Métronome" },
        }},
        { id = "nature",    name = "Nature", words = {
            e = { "Soleil","Nuage","Arbre","Rivière","Fleur","Pluie","Arc-en-ciel","Rocher","Étoile","Vague" },
            m = { "Tornade","Aurore boréale","Stalactite","Glacier","Foudre","Marécage","Dune","Volcan","Geysir","Tourbillon" },
            h = { "Éclipse","Moraine","Embrun","Crevasse","Confluent","Épiphyte","Karst","Limon","Atoll","Sérac" },
        }},
        { id = "activites", name = "Activités", words = {
            e = { "Courir","Nager","Chanter","Danser","Peindre","Cuisiner","Lire","Jardiner","Grimper","Sauter" },
            m = { "Tricoter","Escalader","Surfer","Méditer","Sculpter","Jongler","Plonger","Camper","Tracter","Souffler" },
            h = { "Distiller","Broder","Cartographier","Fermenter","Labouver","Émailler","Calligraphier","Spéléologuer","Équilibrer","Scarifier" },
        }},
    },
    en = {
        { id = "animals",    name = "Animals", words = {
            e = { "Cat","Dog","Horse","Lion","Rabbit","Cow","Duck","Frog","Fish","Bird" },
            m = { "Giraffe","Crocodile","Penguin","Dolphin","Kangaroo","Octopus","Flamingo","Bison","Fox","Owl" },
            h = { "Platypus","Axolotl","Pangolin","Narwhal","Tapir","Armadillo","Okapi","Lemur","Monitor lizard","Mantis" },
        }},
        { id = "jobs",       name = "Jobs", words = {
            e = { "Doctor","Firefighter","Police","Baker","Dentist","Nurse","Pilot","Postman","Cook","Teacher" },
            m = { "Architect","Plumber","Surgeon","Journalist","Photographer","Accountant","Geologist","Diplomat","Vet","Pharmacist" },
            h = { "Astrophysicist","Entomologist","Paleontologist","Cartographer","Cryptologist","Epidemiologist","Puppeteer","Luthier","Auctioneer","Sommelier" },
        }},
        { id = "sports",     name = "Sports", words = {
            e = { "Football","Tennis","Swimming","Skiing","Boxing","Golf","Rugby","Judo","Cycling","Basketball" },
            m = { "Fencing","Rowing","Badminton","Horse riding","Diving","Handball","Biathlon","Curling","Volleyball","Triathlon" },
            h = { "Bobsleigh","Pentathlon","Lacrosse","Kitesurfing","Luge","Squash","Skeleton","Sumo","Polo","Kabaddi" },
        }},
        { id = "food",       name = "Food", words = {
            e = { "Pizza","Cake","Bread","Cheese","Soup","Ice cream","Salad","Pancake","Spaghetti","Omelette" },
            m = { "Quiche","Fondue","Ratatouille","Couscous","Risotto","Paella","Meringue","Artichoke","Sushi","Lasagna" },
            h = { "Bourguignon","Mille-feuille","Bouillabaisse","Cassoulet","Profiteroles","Blanquette","Gougères","Croquembouche","Vichyssoise","Crème brûlée" },
        }},
        { id = "places",     name = "Places", words = {
            e = { "Beach","Mountain","Forest","Station","Airport","Market","Church","School","Hospital","Castle" },
            m = { "Desert","Volcano","Lighthouse","Mosque","Fjord","Monastery","Stadium","Library","Cave","Harbor" },
            h = { "Catacombs","Atoll","Pagoda","Estuary","Bunker","Labyrinth","Megalith","Cistern","Crypt","Leprosarium" },
        }},
        { id = "objects",    name = "Objects", words = {
            e = { "Key","Chair","Lamp","Phone","Bag","Book","Clock","Umbrella","Ball","Hammer" },
            m = { "Microscope","Telescope","Accordion","Hourglass","Compass","Watering can","Swing","Fan","Trampoline","Harmonica" },
            h = { "Sextant","Alembic","Tripod","Corkscrew","Bellows","Rain gauge","Set square","Bottle opener","Astrolabe","Metronome" },
        }},
        { id = "nature",     name = "Nature", words = {
            e = { "Sun","Cloud","Tree","River","Flower","Rain","Rainbow","Rock","Star","Wave" },
            m = { "Tornado","Northern lights","Stalactite","Glacier","Lightning","Swamp","Sand dune","Volcano","Geyser","Whirlpool" },
            h = { "Eclipse","Moraine","Sea spray","Crevasse","Confluence","Epiphyte","Karst","Silt","Atoll","Serac" },
        }},
        { id = "activities", name = "Activities", words = {
            e = { "Run","Swim","Sing","Dance","Paint","Cook","Read","Garden","Climb","Jump" },
            m = { "Knit","Climb","Surf","Meditate","Sculpt","Juggle","Dive","Camp","Tow","Blow" },
            h = { "Distil","Embroider","Map","Ferment","Plough","Enamel","Calligraph","Spelunk","Balance","Scarify" },
        }},
    },
}
