import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';

const kOpenAiToken = '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';

final openAI = OpenAI.instance.build(
  token: kOpenAiToken,
  baseOption: HttpSetup(receiveTimeout: const Duration(seconds: 15)),
);
Future<AiModel> modelDataList() async {
  return await OpenAI.instance.build(token: kOpenAiToken).listModel();
}

Future<EngineModel> engineList() async {
  return await OpenAI.instance.build(token: kOpenAiToken).listEngine();
}

const kPrompt = '''
Pretend like you are an api that takes an OCR Scan of a groceries receipt and responds with a json serializable list. 

Reply with only a list of ingredients and nothing else. Make sure to use title case and the result is json serializable. 

Remove any brand names and quantities.

Also predict the shelve life in days for each item and return that in the json list as an object. Use the keys shelf_life and ingredient only 

If you can not identify any ingredients, respond with '[]' only without any explanation


your response must be json serializable and you should never provide an explanation.

OCR SCAN:''';

String getSuggestRecipe(String type, List<String> ingredients) {
  return 'A $type dish made from ${ingredients.join(', ')}';
}
