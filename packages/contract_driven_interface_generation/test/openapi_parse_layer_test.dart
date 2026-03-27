import 'dart:convert';

import 'package:contract_driven_interface_generation/contract_driven_interface_generation.dart';
import 'package:test/test.dart';

void main() {
  test('mergeOpenApiDocuments merges paths and schemas', () {
    final a = OpenApiDocumentLoader.parseString(
      '''
openapi: 3.0.0
info:
  title: A
  version: "1"
paths:
  /x:
    get:
      tags: [T]
      responses:
        "200":
          description: ok
components:
  schemas:
    Foo:
      type: object
''',
      isJson: false,
    );
    final b = OpenApiDocumentLoader.parseString(
      '''
openapi: 3.0.0
paths:
  /x:
    post:
      tags: [T]
      responses:
        "200":
          description: ok
  /y:
    get:
      responses:
        "200":
          description: ok
components:
  schemas:
    Foo:
      type: string
    Bar:
      type: object
''',
      isJson: false,
    );
    final m = mergeOpenApiDocuments([a, b]);
    final paths = m['paths'] as Map<String, dynamic>;
    expect(paths.length, 2);
    final x = paths['/x'] as Map<String, dynamic>;
    expect(x.containsKey('get'), isTrue);
    expect(x.containsKey('post'), isTrue);
    final comp = m['components'] as Map<String, dynamic>;
    final schemas = (comp['schemas'] as Map).cast<String, dynamic>();
    expect(schemas['Foo'], isA<Map<String, dynamic>>());
    expect((schemas['Foo'] as Map<String, dynamic>)['type'], 'string');
    expect(schemas.containsKey('Bar'), isTrue);
  });

  test('parseOpenApiDocument exposes servers, security, operations', () {
    final spec = OpenApiDocumentLoader.parseString(
      r'''
openapi: 3.0.1
info:
  title: API
  version: "2"
servers:
  - url: https://api.example.com/v1
    description: prod
components:
  securitySchemes:
    bearer:
      type: http
      scheme: bearer
  schemas:
    Pet:
      type: object
      properties:
        id:
          type: integer
paths:
  /pets/{id}:
    parameters:
      - name: id
        in: path
        required: true
        schema:
          type: string
    get:
      tags: [pets]
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
            enum: [a, b]
      responses:
        "200":
          description: ok
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Pet'
''',
      isJson: false,
    );
    final doc = parseOpenApiDocument(spec);
    expect(doc.kind, OpenApiSpecKind.openApi3);
    expect(doc.info?.title, 'API');
    expect(doc.servers.single.url, 'https://api.example.com/v1');
    expect(doc.securitySchemes.containsKey('bearer'), isTrue);
    expect(doc.schemas.containsKey('Pet'), isTrue);
    expect(doc.operations.length, 1);
    final op = doc.operations.single;
    expect(op.path, '/pets/{id}');
    expect(op.method, 'get');
    expect(op.successJsonSchemaRef, 'Pet');
    final idParam = op.parameters.where((p) => p.name == 'id').single;
    expect(idParam.enumValues, ['a', 'b']);
    expect(doc.warnings, isEmpty);
  });

  test('collectExternalRefWarnings lists non-hash refs', () {
    final spec = OpenApiDocumentLoader.parseString(
      r'''
openapi: 3.0.0
info:
  title: X
  version: "1"
paths: {}
components:
  schemas:
    A:
      properties:
        x:
          $ref: './other.yaml#/components/schemas/B'
''',
      isJson: false,
    );
    final w = collectExternalRefWarnings(spec);
    expect(w, contains('./other.yaml#/components/schemas/B'));
  });

  test('filters exclude operation by tag', () {
    final spec = OpenApiDocumentLoader.parseString(
      '''
openapi: 3.0.0
info:
  title: X
  version: "1"
paths:
  /a:
    get:
      tags: [Internal]
      responses:
        "200":
          description: ok
  /b:
    get:
      tags: [Public]
      responses:
        "200":
          description: ok
''',
      isJson: false,
    );
    final doc = parseOpenApiDocument(
      spec,
      filters: const OpenApiFiltersConfig(excludeTags: ['Internal']),
    );
    expect(doc.operations.length, 1);
    expect(doc.operations.single.path, '/b');
    expect(doc.filteredPathCount, 1);
  });

  test('encodeParsedOpenApiDocumentJson produces valid JSON', () {
    final spec = OpenApiDocumentLoader.parseString(
      '''
openapi: 3.0.0
info:
  title: T
  version: "1"
paths:
  /a:
    get:
      responses:
        "200":
          description: ok
''',
      isJson: false,
    );
    final doc = parseOpenApiDocument(spec);
    final json = encodeParsedOpenApiDocumentJson(doc);
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    expect(decoded['kind'], 'openApi3');
    expect((decoded['info'] as Map<String, dynamic>)['title'], 'T');
    expect((decoded['operations'] as List<dynamic>).length, 1);
  });

  test('resolveLocalSchemaRef returns registered schema', () {
    final spec = OpenApiDocumentLoader.parseString(
      '''
openapi: 3.0.0
paths: {}
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
    final reg = buildSchemaRegistry(spec);
    final pet = resolveLocalSchemaRef(reg, '#/components/schemas/Pet');
    expect(pet?['type'], 'object');
  });

  test('requestBody schema oneOf picks first schema ref', () {
    final spec = OpenApiDocumentLoader.parseString(
      r'''
openapi: 3.0.0
info:
  title: T
  version: "1"
paths:
  /auth/login:
    post:
      tags: [Auth]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              oneOf:
                - type: object
                - $ref: '#/components/schemas/models.LoginRequest'
      responses:
        "200":
          description: ok
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/models.TokenOut'
components:
  schemas:
    models.LoginRequest:
      type: object
      properties:
        phone:
          type: string
    models.TokenOut:
      type: object
''',
      isJson: false,
    );
    final doc = parseOpenApiDocument(spec);
    final login = doc.operations.firstWhere((o) => o.path == '/auth/login');
    expect(login.requestBody?.jsonSchemaRef, 'models.LoginRequest');
    final ok = login.responsesByCode['200'];
    expect(ok?.jsonSchemaRef, 'models.TokenOut');
  });
}
