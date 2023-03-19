import 'dart:convert';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:keep_fresh/utils/generative_ai.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:keep_fresh/custom_icons.dart';
import 'package:timeago/timeago.dart';

final Map<String, String> imageUrls = {};
final Map<String, String> cachedPrompts = {};

const neutral30 = Color.fromRGBO(193, 193, 193, 1);
const tileColor = Color.fromRGBO(90, 90, 90, 1);
const suggestedRecipeCardColor = Color.fromRGBO(72, 68, 68, 1);

// Override "en" locale messages with custom messages that are more precise and short
final _ = timeago.setLocaleMessages('en', MyCustomMessages());

// my_custom_messages.dart
class MyCustomMessages implements LookupMessages {
  @override
  String prefixAgo() => '';
  @override
  String prefixFromNow() => '';
  @override
  String suffixAgo() => '';
  @override
  String suffixFromNow() => '';
  @override
  String lessThanOneMinute(int seconds) => 'now';
  @override
  String aboutAMinute(int minutes) => '${minutes}m';
  @override
  String minutes(int minutes) => '${minutes}m';
  @override
  String aboutAnHour(int minutes) => '${minutes}m';
  @override
  String hours(int hours) => '${hours}h';
  @override
  String aDay(int hours) => '${hours}h';
  @override
  String days(int days) => days > 7 ? '${days ~/ 7} Weeks' : '$days Days';
  @override
  String aboutAMonth(int days) => '${days}d';
  @override
  String months(int months) => '${months}mo';
  @override
  String aboutAYear(int year) => '${year}y';
  @override
  String years(int years) => '${years}y';
  @override
  String wordSeparator() => ' ';
}

class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key, required this.title});

  final String title;

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  final homePageIngredients = [
    Ingredient('Bread', 5),
    Ingredient('Eggs', 2),
    Ingredient('Milk', 1),
    Ingredient('Butter', 4),
    Ingredient('Vanilla', 2),
  ];
  int index = 0;
  String selectedRecipeType = suggestedRecipes.first;

  @override
  Widget build(BuildContext context) {
    var icons = [
      KeepFreshIcons.homeIcon,
      KeepFreshIcons.bookIcon,
      KeepFreshIcons.pantryIcon,
      KeepFreshIcons.notificationIcon,
      KeepFreshIcons.profileIcon,
    ];
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.black,
      bottomNavigationBar: CurvedNavigationBar(
          backgroundColor: Colors.transparent,
          onTap: (i) async {
            if (i == index && index == 2) {
              String text = await getReceiptScan();
              final request = ChatCompleteText(
                  maxToken: 3000,
                  model: kChatGptTurbo0301Model,
                  messages: [
                    {'role': 'user', 'content': '''$kPrompt $text'''}
                  ]);
              final chatStream = openAI.onChatCompletion(request: request);

              // ignore: use_build_context_synchronously
              final newIngredients = await showDialog<List<Ingredient>>(
                  context: context,
                  builder: (context) => FutureBuilder<ChatCTResponse?>(
                      future: chatStream,
                      builder: (context, snapshot) {
                        final result = snapshot.data?.choices
                            .map((e) => e.message.content)
                            .last;

                        return AlertDialog(
                          actions: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                              onPressed: () {
                                var jsonDecode2 =
                                    (jsonDecode(result!.trim()) as List);
                                Navigator.pop(
                                    context,
                                    jsonDecode2
                                        .map((e) => e as Map<String, dynamic>)
                                        .toList()
                                        .map((e) => Ingredient(
                                            e['ingredient'] as String,
                                            e['shelf_life'] as int))
                                        .toList());
                              },
                              label: const Text('Done'),
                              icon: const Icon(Icons.done),
                            )
                          ],
                          title: const Text('Scanned Ingredients'),
                          content: result == null
                              ? CircularProgressIndicator.adaptive()
                              : Wrap(
                                  spacing: 10,
                                  children: [
                                    ...(jsonDecode(result.trim()) as List)
                                        .map((e) => Chip(
                                              avatar: CircleAvatar(
                                                  child: Text(
                                                      (e['shelf_life'] as int)
                                                          .toString())),
                                              label: Text(
                                                  e['ingredient'] as String),
                                              backgroundColor: Colors.redAccent,
                                              labelStyle: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16),
                                            ))
                                  ],
                                ),
                        );
                      }));
              final names = homePageIngredients.map((e) => e.name).toSet();
              for (final Ingredient newIngredient in (newIngredients ?? [])) {
                if (!names.contains(newIngredient.name)) {
                  homePageIngredients.add(newIngredient);
                }
              }
            }
            setState(() {
              index = i;
            });
          },
          buttonBackgroundColor: Colors.red,
          items: icons.asMap().entries.map((entry) {
            return Icon(
              (2 == entry.key) && (entry.key == index)
                  ? Icons.add
                  : entry.value,
              size: 40,
              color: entry.key == index ? Colors.white : neutral30,
            );
          }).toList()),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.only(top: 100, bottom: 100)
              .add(const EdgeInsets.symmetric(horizontal: 10)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const Title(
                text: 'Curated Meals Based on Your Pantry',
              ),
              Image.asset('assets/images/home_recipe_image.png'),
              Column(
                children: [
                  for (final ingredient in homePageIngredients)
                    Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 5),
                      child: ListTile(
                        leading: FutureBuilder(
                            future: generateIngredientImage(ingredient.name),
                            builder: (ctx, f) => Container(
                                  height: 60,
                                  width: 60,
                                  padding: EdgeInsets.all(4),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: f.data ??
                                        Container(
                                          height: 10,
                                          width: 40,
                                        ),
                                  ),
                                )),
                        shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12))),
                        title: Text(
                          ingredient.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                        trailing: Text(
                          'Expires: ${ingredient.shelf_life} Days',
                          style: const TextStyle(
                            color: neutral30,
                            fontSize: 16,
                          ),
                        ),
                        tileColor: tileColor,
                      ),
                    )
                ],
              ),
              Row(
                children: const [
                  Title(
                    text: 'Suggested Recipes',
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
              const Text(
                'Based on the ingredients you already own, here are some delicious recipes to try out',
                style: TextStyle(color: neutral30),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Theme(
                  data: Theme.of(context).copyWith(useMaterial3: true),
                  child: Row(
                    children: [
                      for (final type in suggestedRecipes)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          child: ActionChip(
                              onPressed: () => setState(() {
                                    selectedRecipeType = type;
                                  }),
                              backgroundColor: type != selectedRecipeType
                                  ? Colors.white
                                  : Colors.red,
                              label: Text(
                                type,
                                style: TextStyle(
                                    color: type == selectedRecipeType
                                        ? Colors.white
                                        : Colors.red),
                              )),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: FutureBuilder(
                    future: generateSuggestedRecipeImage(selectedRecipeType,
                        homePageIngredients.map((e) => e.name).toList()),
                    builder: (ctx, f) {
                      var data = f.data;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40),
                            ),
                            margin: EdgeInsets.only(top: 200),
                            color: suggestedRecipeCardColor,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Text(
                                    data?.title ?? '',
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontFamily: 'Poppins',
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  Text(data?.recipe ?? '',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 40,
                            child: Container(
                              height: 200,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: data?.image ??
                                    CircularProgressIndicator.adaptive(),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<SuggestedRecipeCardData?> generateSuggestedRecipeImage(
      String type, List<String> ingredients) async {
    final prompt = '''
Create a description for a dish made of the following ingredients. The description has to be visual and appetizing and very short. The type of dish has to be $type.
Ingredients ${ingredients.join()}
''';
    final titlePrompt = '''
Create a three word title for a dish made of the following ingredients.
Ingredients ${ingredients.join()} that is a $type dish
''';

    String content =
        cachedPrompts[prompt] ?? await getContentFromPrompt(prompt);
    String title = cachedPrompts[titlePrompt] ??
        await getContentFromPrompt(titlePrompt, 10);

    return SuggestedRecipeCardData(
        (await generateIngredientImage(content, ImageSize.size512))!,
        content,
        title);
  }

  Future<String> getContentFromPrompt(String prompt,
      [int maxToken = 500]) async {
    if (cachedPrompts[prompt] == null) {
      var chatCTResponse = (await openAI.onChatCompletion(
          request: ChatCompleteText(
              maxToken: maxToken,
              model: kChatGptTurbo0301Model,
              messages: [
            {'role': 'user', 'content': prompt}
          ])));
      var content = chatCTResponse!.choices.last.message.content;
      cachedPrompts[prompt] ??= content;
    }

    return cachedPrompts[prompt]!;
  }

  Future<Image?> generateIngredientImage(String prompt,
      [ImageSize? imageSize]) async {
    if (imageUrls[prompt] != null) {
      return Image.network(imageUrls[prompt]!);
    }
    final imageRequest =
        GenerateImage(prompt, 1, size: imageSize ?? ImageSize.size256);
    final response = await openAI.generateImage(imageRequest);
    final url = response?.data?.first?.url;
    if (url == null) return null;
    imageUrls[prompt] = url;
    return Image.network(url);
  }

  Future<String> getReceiptScan() async {
    final imPath = await CunningDocumentScanner.getPictures();
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    final RecognizedText recognizedText = await textRecognizer
        .processImage(InputImage.fromFilePath(imPath!.first));

    String text = recognizedText.text;
    print(text);

    return text;
  }
}

class Title extends StatelessWidget {
  const Title({
    required this.text,
    this.textAlign,
    super.key,
  });

  final String text;
  final TextAlign? textAlign;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: const TextStyle(
          fontSize: 24,
          fontFamily: 'Poppins',
          color: Colors.white,
          fontWeight: FontWeight.w600),
    );
  }
}

const suggestedRecipes = ['Salad', 'Breakfast', 'Appetizer', 'Dinner', 'Lunch'];

class Ingredient {
  final String name;
  // ignore: non_constant_identifier_names
  final int shelf_life;

  Ingredient(this.name, this.shelf_life);
}

final now = DateTime.now();

class SuggestedRecipeCardData {
  final Image image;
  final String recipe;
  final String title;

  SuggestedRecipeCardData(this.image, this.recipe, this.title);
}
