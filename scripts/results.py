#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
resumen_scoreboard.py

Resume los archivos scoreboard.csv que produce fpu_scoreboard_c en tablas
por operacion y modo de redondeo.

Columnas, en dos bloques separados por "|":

  criterio estricto (bit-exacto, IEEE 754)
    TOTAL    filas de esa operacion y modo (PASS + FAIL + BUG)
    PASS     clasificacion == PASS
    FAIL     clasificacion == FAIL
    F1ULP    subconjunto de FAIL con dist_ulp == 1
    %PASS    100 * PASS / TOTAL

  criterio relajado a 1 ULP
    PASS_n   PASS + F1ULP
    FAIL_n   FAIL - F1ULP
    %PASS_n  100 * PASS_n / TOTAL

Las transacciones BUG (desviacion documentada del DUT) no tienen columna
propia; cuentan en TOTAL y se avisan al pie de la tabla cuando existen.

Modos de entrada (excluyentes entre si):
  --test_seed   uno o mas scoreboard.csv (o el directorio de una semilla)
  --test_seeds  uno o mas directorios de test; recorre todas sus semillas
  --all         recorre la raiz de regresion completa (--raiz)
"""

import argparse
import csv
import re
import sys
from pathlib import Path

ORDEN_OPERACIONES = ["FADD", "FSUB", "FMUL", "FMADD", "FMSUB", "FEQ", "FLT", "FLE"]
ORDEN_MODOS_REDONDEO = ["RNE", "RTZ", "RDN", "RUP", "RMM"]
OPERACIONES_COMPARACION = {"FEQ", "FLT", "FLE"}

COLUMNAS_REQUERIDAS = ("op", "rm", "clasificacion", "dist_ulp")
RAIZ_REGRESION_DEFECTO = Path("reportes/ultima")
NOMBRE_ARCHIVO_DEFECTO = "scoreboard.csv"

ANCHO_ETIQUETA = 9
SEPARADOR_BLOQUES = "  |"
COLUMNAS_ESTRICTAS = (("TOTAL", 9), ("PASS", 9), ("FAIL", 8), ("F1ULP", 8), ("%PASS", 9))
COLUMNAS_RELAJADAS = (("PASS_n", 9), ("FAIL_n", 9), ("%PASS_n", 10))


class Conteo:
    """Acumulador de veredictos de una particion (operacion, modo)."""

    __slots__ = ("total", "num_pass", "num_bug", "num_fail", "num_fail_1ulp", "num_otro")

    def __init__(self):
        self.total = 0
        self.num_pass = 0
        self.num_bug = 0
        self.num_fail = 0
        self.num_fail_1ulp = 0
        self.num_otro = 0

    def agregar(self, clasificacion, dist_ulp):
        self.total += 1
        if clasificacion == "PASS":
            self.num_pass += 1
        elif clasificacion == "BUG":
            self.num_bug += 1
        elif clasificacion == "FAIL":
            self.num_fail += 1
            if dist_ulp == 1:
                self.num_fail_1ulp += 1
        else:
            self.num_otro += 1

    def fusionar(self, otro):
        self.total += otro.total
        self.num_pass += otro.num_pass
        self.num_bug += otro.num_bug
        self.num_fail += otro.num_fail
        self.num_fail_1ulp += otro.num_fail_1ulp
        self.num_otro += otro.num_otro

    @property
    def pass_relajado(self):
        return self.num_pass + self.num_fail_1ulp

    @property
    def fail_relajado(self):
        return self.num_fail - self.num_fail_1ulp

    @property
    def pct_pass(self):
        return 100.0 * self.num_pass / self.total if self.total else 0.0

    @property
    def pct_pass_relajado(self):
        return 100.0 * self.pass_relajado / self.total if self.total else 0.0

    def celdas_estrictas(self):
        return (str(self.total), str(self.num_pass), str(self.num_fail),
                str(self.num_fail_1ulp), "{:.2f}%".format(self.pct_pass))

    def celdas_relajadas(self):
        return (str(self.pass_relajado), str(self.fail_relajado),
                "{:.2f}%".format(self.pct_pass_relajado))


class Ejecucion:
    """Un scoreboard.csv con su test, su semilla y sus conteos."""

    def __init__(self, ruta_csv, nombre_test, semilla):
        self.ruta_csv = ruta_csv
        self.nombre_test = nombre_test
        self.semilla = semilla
        self.conteos = {}   # (operacion, modo) -> Conteo
        self.avisos = []

    def agregar(self, operacion, modo, clasificacion, dist_ulp):
        clave = (operacion, modo)
        self.conteos.setdefault(clave, Conteo()).agregar(clasificacion, dist_ulp)

    def operaciones(self):
        return ordenar(set(op for op, _ in self.conteos), ORDEN_OPERACIONES)

    def modos(self, operacion):
        modos = set(modo for op, modo in self.conteos if op == operacion)
        return ordenar(modos, ORDEN_MODOS_REDONDEO)

    def total_operacion(self, operacion):
        acumulado = Conteo()
        for (op, _), conteo in self.conteos.items():
            if op == operacion:
                acumulado.fusionar(conteo)
        return acumulado

    def total(self, filtro_operaciones=None):
        acumulado = Conteo()
        for (op, _), conteo in self.conteos.items():
            if filtro_operaciones and op not in filtro_operaciones:
                continue
            acumulado.fusionar(conteo)
        return acumulado

    def clave_orden(self):
        semilla_numerica = int(self.semilla) if self.semilla.isdigit() else float("inf")
        return (self.nombre_test, semilla_numerica, self.semilla)


# ---------------------------------------------------------------------------
# Lectura
# ---------------------------------------------------------------------------

def plural(cantidad, singular, plural_):
    return "{} {}".format(cantidad, singular if cantidad == 1 else plural_)


def ordenar(valores, orden_canonico):
    """Ordena por el orden canonico; lo desconocido va al final, alfabetico."""
    def clave(valor):
        if valor in orden_canonico:
            return (orden_canonico.index(valor), "")
        return (len(orden_canonico), valor)
    return sorted(valores, key=clave)


def identificar_ejecucion(ruta_csv):
    """Deriva (test, semilla) de reportes/.../<test>/s<semilla>/scoreboard.csv.

    El CSV no lleva la semilla (TODO abierto en csv_abrir), asi que se toma de
    la jerarquia de directorios y, si el nombre no calza, de cmd.txt.
    """
    directorio_semilla = ruta_csv.parent
    directorio_test = directorio_semilla.parent
    semilla = None
    nombre_test = None

    coincidencia = re.fullmatch(r"s?(\d+)", directorio_semilla.name)
    if coincidencia:
        semilla = coincidencia.group(1)
        nombre_test = directorio_test.name
    else:
        nombre_test = directorio_semilla.name

    if semilla is None:
        ruta_cmd = directorio_semilla / "cmd.txt"
        if ruta_cmd.is_file():
            texto = ruta_cmd.read_text(errors="replace")
            hallazgo = re.search(r"(?:ntb_random_seed|[+-]seed)[= ]+(\d+)", texto)
            if hallazgo:
                semilla = hallazgo.group(1)

    return (nombre_test or "?", semilla or "?")


def leer_scoreboard(ruta_csv):
    ejecucion = Ejecucion(ruta_csv, *identificar_ejecucion(ruta_csv))
    with ruta_csv.open(newline="", encoding="utf-8", errors="replace") as manejador:
        lector = csv.DictReader(manejador)
        campos = lector.fieldnames or []
        faltantes = [campo for campo in COLUMNAS_REQUERIDAS if campo not in campos]
        if faltantes:
            raise ValueError("faltan columnas {} en el encabezado".format(", ".join(faltantes)))
        for numero_linea, fila in enumerate(lector, start=2):
            operacion = (fila.get("op") or "").strip()
            modo = (fila.get("rm") or "").strip()
            clasificacion = (fila.get("clasificacion") or "").strip().upper()
            dist_ulp_crudo = (fila.get("dist_ulp") or "").strip()
            try:
                dist_ulp = int(dist_ulp_crudo)
            except ValueError:
                dist_ulp = -1
                if clasificacion == "FAIL":
                    ejecucion.avisos.append("linea {}: dist_ulp no numerico ('{}')".format(
                        numero_linea, dist_ulp_crudo))
            if not operacion or not modo:
                ejecucion.avisos.append(
                    "linea {}: op o rm vacios, fila ignorada".format(numero_linea))
                continue
            if clasificacion not in ("PASS", "BUG", "FAIL"):
                ejecucion.avisos.append("linea {}: clasificacion desconocida ('{}')".format(
                    numero_linea, clasificacion))
            ejecucion.agregar(operacion, modo, clasificacion, dist_ulp)
    return ejecucion


# ---------------------------------------------------------------------------
# Resolucion de rutas de entrada
# ---------------------------------------------------------------------------

def resolver_raiz(raiz_pedida):
    """Acepta la raiz tal cual o la busca en los ancestros del directorio actual."""
    if raiz_pedida.is_dir():
        return raiz_pedida
    if raiz_pedida.is_absolute():
        return None
    directorio_actual = Path.cwd()
    for directorio in [directorio_actual] + list(directorio_actual.parents)[:3]:
        candidata = directorio / raiz_pedida
        if candidata.is_dir():
            return candidata
    return None


def buscar_scoreboards(directorio, nombre_archivo):
    return sorted(ruta for ruta in directorio.rglob(nombre_archivo) if ruta.is_file())


def rutas_desde_archivos(rutas_pedidas, nombre_archivo):
    """--test_seed: cada ruta es un scoreboard.csv o el directorio de una semilla."""
    rutas_csv = []
    for ruta in rutas_pedidas:
        if ruta.is_file():
            rutas_csv.append(ruta)
        elif ruta.is_dir():
            candidata = ruta / nombre_archivo
            if candidata.is_file():
                rutas_csv.append(candidata)
            else:
                print("error: '{}' no contiene '{}', se omite".format(ruta, nombre_archivo),
                      file=sys.stderr)
        else:
            print("error: '{}' no existe, se omite".format(ruta), file=sys.stderr)
    return rutas_csv


def rutas_desde_directorios(directorios_pedidos, nombre_archivo):
    """--test_seeds: cada ruta es un directorio de test; se recorren sus semillas."""
    rutas_csv = []
    for directorio in directorios_pedidos:
        if not directorio.is_dir():
            print("error: '{}' no es un directorio, se omite".format(directorio),
                  file=sys.stderr)
            continue
        encontradas = buscar_scoreboards(directorio, nombre_archivo)
        if not encontradas:
            print("error: no se encontro ningun '{}' bajo '{}'".format(
                nombre_archivo, directorio), file=sys.stderr)
            continue
        rutas_csv.extend(encontradas)
    return rutas_csv


def agrupar_por_test(ejecuciones):
    """Devuelve [(nombre_test, [ejecuciones ordenadas por semilla]), ...]."""
    grupos = {}
    for ejecucion in ejecuciones:
        grupos.setdefault(ejecucion.nombre_test, []).append(ejecucion)
    return [(nombre_test, sorted(lista, key=lambda e: e.clave_orden()))
            for nombre_test, lista in sorted(grupos.items())]


# ---------------------------------------------------------------------------
# Impresion
# ---------------------------------------------------------------------------

def _formatear_celdas(valores, columnas):
    return "".join("{:>{ancho}}".format(valor, ancho=ancho)
                   for valor, (_, ancho) in zip(valores, columnas))


def ancho_tabla(ancho_etiqueta=ANCHO_ETIQUETA):
    return (ancho_etiqueta
            + sum(ancho for _, ancho in COLUMNAS_ESTRICTAS)
            + len(SEPARADOR_BLOQUES)
            + sum(ancho for _, ancho in COLUMNAS_RELAJADAS))


def imprimir_separador(ancho_etiqueta=ANCHO_ETIQUETA):
    print("-" * ancho_tabla(ancho_etiqueta))


def imprimir_cabecera_tabla(etiqueta, ancho_etiqueta=ANCHO_ETIQUETA):
    print("{:<{ancho}}".format(etiqueta, ancho=ancho_etiqueta)
          + _formatear_celdas([titulo for titulo, _ in COLUMNAS_ESTRICTAS], COLUMNAS_ESTRICTAS)
          + SEPARADOR_BLOQUES
          + _formatear_celdas([titulo for titulo, _ in COLUMNAS_RELAJADAS], COLUMNAS_RELAJADAS))
    imprimir_separador(ancho_etiqueta)


def imprimir_fila(etiqueta, conteo, ancho_etiqueta=ANCHO_ETIQUETA):
    print("{:<{ancho}}".format(etiqueta, ancho=ancho_etiqueta)
          + _formatear_celdas(conteo.celdas_estrictas(), COLUMNAS_ESTRICTAS)
          + SEPARADOR_BLOQUES
          + _formatear_celdas(conteo.celdas_relajadas(), COLUMNAS_RELAJADAS))


def imprimir_notas(conteo):
    """BUG y clasificaciones desconocidas no tienen columna: se avisan aparte
    porque siguen sumando en TOTAL y por eso PASS + FAIL puede no cuadrar."""
    if conteo.num_bug:
        print("  nota: {} transacciones BUG (desviacion documentada); cuentan en "
              "TOTAL, no en PASS ni FAIL".format(conteo.num_bug))
    if conteo.num_otro:
        print("  nota: {} filas con clasificacion desconocida (cuentan solo en "
              "TOTAL)".format(conteo.num_otro))


def imprimir_avisos(ejecucion, maximo=10):
    for aviso in ejecucion.avisos[:maximo]:
        print("  aviso: {}".format(aviso), file=sys.stderr)
    if len(ejecucion.avisos) > maximo:
        print("  aviso: {} avisos adicionales omitidos".format(len(ejecucion.avisos) - maximo),
              file=sys.stderr)


def operaciones_visibles(ejecucion, filtro_operaciones):
    return [operacion for operacion in ejecucion.operaciones()
            if not filtro_operaciones or operacion in filtro_operaciones]


def imprimir_tabla_resumen_operaciones(ejecucion, filtro_operaciones=None):
    print()
    print("RESUMEN POR OPERACION -- test {} / semilla {}".format(
        ejecucion.nombre_test, ejecucion.semilla))
    imprimir_cabecera_tabla("  OP")
    for operacion in operaciones_visibles(ejecucion, filtro_operaciones):
        imprimir_fila("  " + operacion, ejecucion.total_operacion(operacion))
    imprimir_separador()
    total = ejecucion.total(filtro_operaciones)
    imprimir_fila("  TOTAL", total)
    imprimir_notas(total)


def imprimir_ejecucion(ejecucion, filtro_operaciones=None, detalle_por_modo=True):
    print()
    print("=" * 78)
    print("TEST    : {}".format(ejecucion.nombre_test))
    print("SEMILLA : {}".format(ejecucion.semilla))
    print("ARCHIVO : {}".format(ejecucion.ruta_csv))
    print("=" * 78)

    if detalle_por_modo:
        for operacion in operaciones_visibles(ejecucion, filtro_operaciones):
            marca = " (comparacion: dist_ulp no aplica)" if operacion in OPERACIONES_COMPARACION else ""
            print()
            print("{}{}".format(operacion, marca))
            imprimir_cabecera_tabla("  MODO")
            for modo in ejecucion.modos(operacion):
                imprimir_fila("  " + modo, ejecucion.conteos[(operacion, modo)])
            imprimir_separador()
            imprimir_fila("  TOTAL", ejecucion.total_operacion(operacion))

    imprimir_tabla_resumen_operaciones(ejecucion, filtro_operaciones)
    imprimir_avisos(ejecucion)


def imprimir_resumen_del_test(nombre_test, ejecuciones, filtro_operaciones=None):
    """Tablas resumen de cada semilla del test y, al final, la union de todas."""
    print()
    print("=" * 78)
    print("RESUMEN DEL TEST {} ({})".format(
        nombre_test, plural(len(ejecuciones), "semilla", "semillas")))
    print("=" * 78)

    for ejecucion in ejecuciones:
        imprimir_tabla_resumen_operaciones(ejecucion, filtro_operaciones)

    union_por_operacion = {}
    for ejecucion in ejecuciones:
        for (operacion, _), conteo in ejecucion.conteos.items():
            if filtro_operaciones and operacion not in filtro_operaciones:
                continue
            union_por_operacion.setdefault(operacion, Conteo()).fusionar(conteo)

    semillas = ", ".join(ejecucion.semilla for ejecucion in ejecuciones)
    print()
    print("RESUMEN FINAL -- test {} / union de {} ({})".format(
        nombre_test, plural(len(ejecuciones), "semilla", "semillas"), semillas))
    imprimir_cabecera_tabla("  OP")
    total_test = Conteo()
    for operacion in ordenar(union_por_operacion, ORDEN_OPERACIONES):
        conteo = union_por_operacion[operacion]
        total_test.fusionar(conteo)
        imprimir_fila("  " + operacion, conteo)
    imprimir_separador()
    imprimir_fila("  TOTAL", total_test)
    imprimir_notas(total_test)


def imprimir_consolidado(ejecuciones, filtro_operaciones=None):
    """Tabla por ejecucion y agregado por operacion y modo de toda la corrida."""
    print()
    print("=" * 78)
    print("CONSOLIDADO ({})".format(plural(len(ejecuciones), "archivo", "archivos")))
    print("=" * 78)

    ancho_columna_test = max([len(e.nombre_test) for e in ejecuciones] + [len("TEST")]) + 2
    ancho_columna_semilla = max([len(e.semilla) for e in ejecuciones] + [len("SEMILLA")]) + 2
    ancho_etiqueta = ancho_columna_test + ancho_columna_semilla + 2

    print()
    print("POR EJECUCION")
    imprimir_cabecera_tabla(
        "  {:<{a}}{:<{b}}".format("TEST", "SEMILLA",
                                  a=ancho_columna_test, b=ancho_columna_semilla),
        ancho_etiqueta)
    total_corrida = Conteo()
    for ejecucion in sorted(ejecuciones, key=lambda e: e.clave_orden()):
        conteo = ejecucion.total(filtro_operaciones)
        total_corrida.fusionar(conteo)
        etiqueta = "  {:<{a}}{:<{b}}".format(ejecucion.nombre_test, ejecucion.semilla,
                                             a=ancho_columna_test, b=ancho_columna_semilla)
        imprimir_fila(etiqueta, conteo, ancho_etiqueta)
    imprimir_separador(ancho_etiqueta)
    imprimir_fila("  {:<{a}}{:<{b}}".format("TOTAL", "",
                                            a=ancho_columna_test, b=ancho_columna_semilla),
                  total_corrida, ancho_etiqueta)
    imprimir_notas(total_corrida)

    agregado = {}
    for ejecucion in ejecuciones:
        for clave, conteo in ejecucion.conteos.items():
            if filtro_operaciones and clave[0] not in filtro_operaciones:
                continue
            agregado.setdefault(clave, Conteo()).fusionar(conteo)

    print()
    print("AGREGADO POR OPERACION Y MODO (todas las semillas y tests)")
    for operacion in ordenar(set(op for op, _ in agregado), ORDEN_OPERACIONES):
        print()
        print(operacion)
        imprimir_cabecera_tabla("  MODO")
        total_operacion = Conteo()
        modos = ordenar(set(modo for op, modo in agregado if op == operacion),
                        ORDEN_MODOS_REDONDEO)
        for modo in modos:
            conteo = agregado[(operacion, modo)]
            total_operacion.fusionar(conteo)
            imprimir_fila("  " + modo, conteo)
        imprimir_separador()
        imprimir_fila("  TOTAL", total_operacion)


def exportar_csv(ruta_salida, ejecuciones, filtro_operaciones=None):
    with ruta_salida.open("w", newline="", encoding="utf-8") as manejador:
        escritor = csv.writer(manejador)
        escritor.writerow(["test", "semilla", "op", "rm", "total", "pass", "fail",
                           "fail_1ulp", "pct_pass", "pass_n", "fail_n", "pct_pass_n",
                           "bug", "archivo"])
        for ejecucion in sorted(ejecuciones, key=lambda e: e.clave_orden()):
            for operacion in operaciones_visibles(ejecucion, filtro_operaciones):
                for modo in ejecucion.modos(operacion):
                    conteo = ejecucion.conteos[(operacion, modo)]
                    escritor.writerow([
                        ejecucion.nombre_test, ejecucion.semilla, operacion, modo,
                        conteo.total, conteo.num_pass, conteo.num_fail,
                        conteo.num_fail_1ulp, "{:.4f}".format(conteo.pct_pass),
                        conteo.pass_relajado, conteo.fail_relajado,
                        "{:.4f}".format(conteo.pct_pass_relajado),
                        conteo.num_bug, ejecucion.ruta_csv])
    print("\nResumen exportado en {}".format(ruta_salida))


# ---------------------------------------------------------------------------
# Interfaz de linea de comandos
# ---------------------------------------------------------------------------

AYUDA_EPILOGO = """\
modos de entrada (excluyentes):
  --test_seed  RUTA [RUTA ...]   scoreboard.csv puntual, o el directorio de una
                                 semilla que lo contenga. Sin bandera, las rutas
                                 sueltas se interpretan igual que --test_seed.
  --test_seeds RUTA [RUTA ...]   directorio de un test; recorre todas sus
                                 semillas, imprime el bloque completo de cada
                                 una, luego el resumen por semilla y la union.
  --all                          recorre --raiz completa (por defecto
                                 reportes/regresiones/ultima).

ejemplos:
  %(prog)s --test_seed reportes/regresiones/ultima/fpu_test_cmp/s469078601/scoreboard.csv
  %(prog)s --test_seeds reportes/regresiones/ultima/fpu_test_arith_normal
  %(prog)s --all
  %(prog)s --all --resumen-final
  %(prog)s --test_seeds reportes/regresiones/20260730_211030/fpu_test_rounding --op FADD,FSUB
"""


def construir_parser():
    parser = argparse.ArgumentParser(
        prog="resumen_scoreboard.py",
        description="Resume scoreboard.csv por operacion y modo de redondeo.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=AYUDA_EPILOGO)

    modo = parser.add_mutually_exclusive_group()
    modo.add_argument("--test_seed", "--test-seed", dest="test_seed", nargs="+",
                      type=Path, metavar="RUTA",
                      help="scoreboard.csv puntual (o directorio de una semilla)")
    modo.add_argument("--test_seeds", "--test-seeds", dest="test_seeds", nargs="+",
                      type=Path, metavar="RUTA",
                      help="directorio de test; recorre todas sus semillas")
    modo.add_argument("--all", action="store_true", dest="todos",
                      help="recorre la raiz de regresion completa")

    parser.add_argument("rutas", nargs="*", type=Path, metavar="RUTA",
                        help=argparse.SUPPRESS)
    parser.add_argument("--raiz", type=Path, default=RAIZ_REGRESION_DEFECTO,
                        help="raiz de busqueda para --all (por defecto %(default)s)")
    parser.add_argument("--nombre", default=NOMBRE_ARCHIVO_DEFECTO, metavar="ARCHIVO",
                        help="nombre del CSV a buscar (por defecto %(default)s)")
    parser.add_argument("--op", default="", metavar="LISTA",
                        help="filtra operaciones separadas por coma (ej. FMADD,FADD)")
    parser.add_argument("--resumen", action="store_true",
                        help="omite el desglose por modo y deja solo el resumen por operacion")
    parser.add_argument("--resumen-final", "--resumen_final", action="store_true",
                        dest="resumen_final",
                        help="omite los bloques por archivo y deja solo las tablas finales")
    parser.add_argument("--csv-salida", "--csv_salida", dest="csv_salida",
                        type=Path, default=None, metavar="ARCHIVO",
                        help="exporta el resumen (una fila por test/semilla/op/modo)")
    return parser


def resolver_entradas(args, parser):
    """Devuelve (modo, rutas_csv). modo en {'test_seed', 'test_seeds', 'all'}."""
    if args.todos:
        if args.rutas:
            parser.error("--all no admite rutas sueltas")
        raiz = resolver_raiz(args.raiz)
        if raiz is None:
            print("error: no existe el directorio '{}' (ni bajo los ancestros de {})".format(
                args.raiz, Path.cwd()), file=sys.stderr)
            return ("all", [])
        rutas_csv = buscar_scoreboards(raiz, args.nombre)
        if not rutas_csv:
            print("error: no se encontro ningun '{}' bajo {}".format(args.nombre, raiz),
                  file=sys.stderr)
        return ("all", rutas_csv)

    if args.test_seeds:
        if args.rutas:
            parser.error("--test_seeds no admite rutas sueltas adicionales")
        return ("test_seeds", rutas_desde_directorios(args.test_seeds, args.nombre))

    rutas_pedidas = list(args.test_seed or []) + list(args.rutas)
    if not rutas_pedidas:
        return (None, [])
    return ("test_seed", rutas_desde_archivos(rutas_pedidas, args.nombre))


def main(argv=None):
    parser = construir_parser()
    args = parser.parse_args(argv)
    filtro_operaciones = {op.strip().upper() for op in args.op.split(",") if op.strip()} or None

    modo, rutas_csv = resolver_entradas(args, parser)
    if modo is None:
        parser.print_help()
        return 2
    if not rutas_csv:
        return 2

    ejecuciones = []
    for ruta_csv in rutas_csv:
        try:
            ejecuciones.append(leer_scoreboard(ruta_csv))
        except (OSError, ValueError) as error:
            print("error: '{}' no se pudo procesar ({})".format(ruta_csv, error),
                  file=sys.stderr)

    if not ejecuciones:
        print("error: ningun archivo valido", file=sys.stderr)
        return 1

    ejecuciones.sort(key=lambda ejecucion: ejecucion.clave_orden())

    if filtro_operaciones:
        vacias = [e for e in ejecuciones if not operaciones_visibles(e, filtro_operaciones)]
        for ejecucion in vacias:
            print("aviso: '{}' no tiene transacciones de {}, se omite".format(
                ejecucion.ruta_csv, ",".join(sorted(filtro_operaciones))), file=sys.stderr)
        ejecuciones = [e for e in ejecuciones if operaciones_visibles(e, filtro_operaciones)]
        if not ejecuciones:
            print("error: el filtro --op dejo todos los archivos vacios", file=sys.stderr)
            return 1

    if not args.resumen_final:
        for ejecucion in ejecuciones:
            imprimir_ejecucion(ejecucion, filtro_operaciones,
                               detalle_por_modo=not args.resumen)

    if modo == "test_seeds":
        grupos = agrupar_por_test(ejecuciones)
        for nombre_test, ejecuciones_del_test in grupos:
            imprimir_resumen_del_test(nombre_test, ejecuciones_del_test, filtro_operaciones)
        if len(grupos) > 1:
            imprimir_consolidado(ejecuciones, filtro_operaciones)
    elif modo == "all":
        imprimir_consolidado(ejecuciones, filtro_operaciones)
    elif len(ejecuciones) > 1:
        imprimir_consolidado(ejecuciones, filtro_operaciones)

    if args.csv_salida:
        exportar_csv(args.csv_salida, ejecuciones, filtro_operaciones)

    return 0


if __name__ == "__main__":
    sys.exit(main())