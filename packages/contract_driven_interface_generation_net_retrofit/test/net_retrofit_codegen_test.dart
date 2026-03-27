import 'dart:io';

import 'package:contract_driven_interface_generation/contract_driven_interface_generation.dart';
import 'package:contract_driven_interface_generation_net_retrofit/contract_driven_interface_generation_net_retrofit.dart';
import 'package:test/test.dart';

void main() {
  test('writeNetRetrofitCodegen emits NetApi + path constants + model',
      () async {
    final spec = OpenApiDocumentLoader.parseString(
      r'''
openapi: 3.0.0
info:
  title: T
  version: "1"
paths:
  /pets/{id}:
    get:
      tags: [pets]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        "200":
          description: ok
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Pet'
components:
  schemas:
    Pet:
      type: object
      properties:
        name:
          type: string
''',
      isJson: false,
    );
    final doc = parseOpenApiDocument(spec);
    final dir = Directory.systemTemp.createTempSync('cdig_net_');
    try {
      final res = await writeNetRetrofitCodegen(
        document: doc,
        rawSpec: spec,
        outputRootAbsolute: dir.path,
        dirs: CdigDirs.defaults,
        tagToFilePrefix: const {},
        netApiClient: 'test_lane',
      );
      expect(res.writtenPaths, isNotEmpty);
      final iface = res.writtenPaths.firstWhere(
        (p) => p.endsWith('pets_interfaces.dart'),
      );
      final text = await File(iface).readAsString();
      expect(text, contains("client: 'test_lane'"));
      expect(text, contains('abstract class PetsServer'));
      expect(text, contains('@Get('));
      expect(text, contains("@Path('id')"));
      final apiPath = res.writtenPaths.firstWhere(
        (p) => p.endsWith('pets_api.dart'),
      );
      final apiText = await File(apiPath).readAsString();
      expect(apiText, contains('class PetsApi'));
      expect(
        res.writtenPaths.any((p) => p.endsWith('openapi_error_codes.dart')),
        isTrue,
      );
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('openapi_error_codes.dart aggregates HTTP + schema code enum', () async {
    final spec = OpenApiDocumentLoader.parseString(
      r'''
openapi: 3.0.0
info: { title: T, version: "1" }
paths:
  /x:
    get:
      tags: [a]
      responses:
        "404": { description: n }
        "500": { description: e }
components:
  schemas:
    Err:
      type: object
      properties:
        code:
          type: integer
          enum: [1001, 9001]
''',
      isJson: false,
    );
    final doc = parseOpenApiDocument(spec);
    final dir = Directory.systemTemp.createTempSync('cdig_ec_');
    try {
      final res = await writeNetRetrofitCodegen(
        document: doc,
        rawSpec: spec,
        outputRootAbsolute: dir.path,
        dirs: CdigDirs.defaults,
        tagToFilePrefix: const {},
      );
      final ec = res.writtenPaths.firstWhere(
        (p) => p.endsWith('openapi_error_codes.dart'),
      );
      final text = await File(ec).readAsString();
      expect(text, contains('static const int notFound = 404'));
      expect(text, contains('static const int internalServerError = 500'));
      expect(text, contains('static const int err1001 = 1001'));
      expect(text, contains('static const int err9001 = 9001'));
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('dirs.errorCodes empty skips openapi_error_codes.dart', () async {
    final spec = OpenApiDocumentLoader.parseString(
      r'''
openapi: 3.0.0
info: { title: T, version: "1" }
paths:
  /x:
    get:
      tags: [a]
      responses:
        "404": { description: n }
''',
      isJson: false,
    );
    final doc = parseOpenApiDocument(spec);
    final dir = Directory.systemTemp.createTempSync('cdig_ec_off_');
    try {
      final res = await writeNetRetrofitCodegen(
        document: doc,
        rawSpec: spec,
        outputRootAbsolute: dir.path,
        dirs: const CdigDirs(
          apis: 'apis',
          interfaces: 'interfaces',
          dto: 'models/dto',
          vo: 'models/vo',
          errorCodes: '',
        ),
        tagToFilePrefix: const {},
      );
      expect(
        res.writtenPaths.any((p) => p.endsWith('openapi_error_codes.dart')),
        isFalse,
      );
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  // unwrap_success_data：默认剥 data vs 保留整包（含 BaseVo 命名）。
  group('unwrap_success_data 案例', () {
    test('默认 true：PetApiResponse 剥 data，@DataPath + 内层 Pet', () async {
      final spec = OpenApiDocumentLoader.parseString(
        _yamlPetApiResponseEnvelope,
        isJson: false,
      );
      final doc = parseOpenApiDocument(spec);
      final dir = Directory.systemTemp.createTempSync('cdig_net_unwrap_true_');
      try {
        final res = await writeNetRetrofitCodegen(
          document: doc,
          rawSpec: spec,
          outputRootAbsolute: dir.path,
          dirs: CdigDirs.defaults,
          tagToFilePrefix: const {},
          // unwrapSuccessData 省略 = 默认 true
        );
        final iface = res.writtenPaths.firstWhere(
          (p) => p.endsWith('pets_interfaces.dart'),
        );
        final text = await File(iface).readAsString();
        expect(text, contains("@DataPath('data')"));
        expect(text, contains('Future<Pet?>'));
        expect(text, contains("import '../models/vo/pet.dart'"));
        expect(text, isNot(contains('PetApiResponse')));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('false：保留 PetApiResponse，无 @DataPath', () async {
      final spec = OpenApiDocumentLoader.parseString(
        _yamlPetApiResponseEnvelope,
        isJson: false,
      );
      final doc = parseOpenApiDocument(spec);
      final dir = Directory.systemTemp.createTempSync('cdig_net_env_');
      try {
        final res = await writeNetRetrofitCodegen(
          document: doc,
          rawSpec: spec,
          outputRootAbsolute: dir.path,
          dirs: CdigDirs.defaults,
          tagToFilePrefix: const {},
          unwrapSuccessData: false,
        );
        final iface = res.writtenPaths.firstWhere(
          (p) => p.endsWith('pets_interfaces.dart'),
        );
        final text = await File(iface).readAsString();
        expect(text, isNot(contains('@DataPath')));
        expect(text, contains('Future<PetApiResponse?>'));
        expect(text, contains("import '../models/vo/pet_api_response.dart'"));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('BaseVo：true 剥至 ItemVo；false 返回 BaseVo 整包', () async {
      final spec = OpenApiDocumentLoader.parseString(
        _yamlBaseVoEnvelope,
        isJson: false,
      );
      final doc = parseOpenApiDocument(spec);

      final dirTrue = Directory.systemTemp.createTempSync('cdig_basevo_t_');
      try {
        final resTrue = await writeNetRetrofitCodegen(
          document: doc,
          rawSpec: spec,
          outputRootAbsolute: dirTrue.path,
          dirs: CdigDirs.defaults,
          tagToFilePrefix: const {},
          unwrapSuccessData: true,
        );
        final ifaceTrue = resTrue.writtenPaths.firstWhere(
          (p) => p.endsWith('pets_interfaces.dart'),
        );
        final textTrue = await File(ifaceTrue).readAsString();
        expect(textTrue, contains("@DataPath('data')"));
        expect(textTrue, contains('Future<ItemVo?>'));
        expect(textTrue, contains("import '../models/vo/item_vo.dart'"));
      } finally {
        dirTrue.deleteSync(recursive: true);
      }

      final dirFalse = Directory.systemTemp.createTempSync('cdig_basevo_f_');
      try {
        final resFalse = await writeNetRetrofitCodegen(
          document: doc,
          rawSpec: spec,
          outputRootAbsolute: dirFalse.path,
          dirs: CdigDirs.defaults,
          tagToFilePrefix: const {},
          unwrapSuccessData: false,
        );
        final ifaceFalse = resFalse.writtenPaths.firstWhere(
          (p) => p.endsWith('pets_interfaces.dart'),
        );
        final textFalse = await File(ifaceFalse).readAsString();
        expect(textFalse, isNot(contains('@DataPath')));
        expect(textFalse, contains('Future<BaseVo?>'));
        expect(textFalse, contains("import '../models/vo/base_vo.dart'"));
      } finally {
        dirFalse.deleteSync(recursive: true);
      }
    });
  });
}

const _yamlPetApiResponseEnvelope = r'''
openapi: 3.0.0
info:
  title: T
  version: "1"
paths:
  /pets/{id}:
    get:
      tags: [pets]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        "200":
          description: ok
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/PetApiResponse'
components:
  schemas:
    PetApiResponse:
      type: object
      properties:
        code:
          type: integer
        message:
          type: string
        data:
          $ref: '#/components/schemas/Pet'
    Pet:
      type: object
      properties:
        name:
          type: string
''';

const _yamlBaseVoEnvelope = r'''
openapi: 3.0.0
info:
  title: T
  version: "1"
paths:
  /pets/{id}:
    get:
      tags: [pets]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        "200":
          description: ok
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/BaseVo'
components:
  schemas:
    BaseVo:
      type: object
      properties:
        code:
          type: integer
        msg:
          type: string
        data:
          $ref: '#/components/schemas/ItemVo'
    ItemVo:
      type: object
      properties:
        id:
          type: string
''';
