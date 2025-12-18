import genanki
import random

def create_anki_deck(deck_name, flashcards, filename="study_deck.apkg"):
    """
    Creates an Anki .apkg file from a list of flashcards.
    
    Args:
        deck_name (str): The title of the deck (e.g., "Linear Programming 101").
        flashcards (list): A list of dicts: [{'front': 'Question', 'back': 'Answer'}]
        filename (str): The output filename.
        
    Returns:
        str: The path to the generated file.
    """
    
    # 1. Define the Card Style (The Model)
    # This defines how the card looks in the Anki app
    my_model = genanki.Model(
        model_id=random.randrange(1 << 30, 1 << 31),
        name='Agent Flashcard Model',
        fields=[
            {'name': 'Question'},
            {'name': 'Answer'},
        ],
        templates=[
            {
                'name': 'Card 1',
                'qfmt': '<div style="text-align: center; font-size: 20px; font-weight: bold;">{{Question}}</div>',
                'afmt': '{{FrontSide}}<hr id="answer"><div style="text-align: center; font-size: 18px;">{{Answer}}</div>',
            },
        ])

    # 2. Initialize the Deck
    my_deck = genanki.Deck(
        deck_id=random.randrange(1 << 30, 1 << 31),
        name=deck_name)

    # 3. Add Cards to the Deck
    for card in flashcards:
        note = genanki.Note(
            model=my_model,
            fields=[card['front'], card['back']]
        )
        my_deck.add_note(note)

    # 4. Generate the File
    genanki.Package(my_deck).write_to_file(filename)
    
    return f"Success: Deck saved to {filename}"