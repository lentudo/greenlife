import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/planta_model.dart';
// 1. IMPORTAMOS EL SERVICIO DE NOTIFICACIONES
import '../services/notification_service.dart';

class DetallePlantaScreen extends StatefulWidget {
  final PlantaModel planta;

  const DetallePlantaScreen({super.key, required this.planta});

  @override
  State<DetallePlantaScreen> createState() => _DetallePlantaScreenState();
}

class _DetallePlantaScreenState extends State<DetallePlantaScreen> {
  late PlantaModel _planta;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _planta = widget.planta;
  }

  // Lógica para calcular el próximo riego (Solo texto visual)
  String _calcularProximoRiego() {
    final fechaProximo = _planta.ultimoRiego.add(Duration(days: _planta.frecuenciaRiego));
    final hoy = DateTime.now();

    final diferencia = fechaProximo.difference(hoy).inDays;

    if (diferencia < 0) return "¡Debiste regarla hace ${diferencia.abs()} días!";
    if (diferencia == 0) return "¡Hoy toca riego!";
    return "Faltan $diferencia días";
  }

  // Función para Regar (Actualizar BD + Programar Notificación)
  Future<void> _regarPlanta() async {
    setState(() => _isLoading = true);
    try {
      final nuevoRiego = DateTime.now();

      // 1. Actualizar en Firebase
      await FirebaseFirestore.instance
          .collection('plantas')
          .doc(_planta.id)
          .update({
        'ultimoRiego': Timestamp.fromDate(nuevoRiego),
      });

      // ---------------------------------------------------------
      // 2. FASE 3: PROGRAMAR LA NOTIFICACIÓN LOCAL
      // ---------------------------------------------------------

      // Calculamos la fecha futura: Hoy + Frecuencia de días
      final proximoRiegoDate = nuevoRiego.add(Duration(days: _planta.frecuenciaRiego));

      await NotificationService.instance.schedulePlantReminder(
        // Usamos hashCode para convertir el ID String de Firebase a un Int único
        id: _planta.id.hashCode,
        title: '🌱 Hora de regar: ${_planta.nombre}',
        body: 'Han pasado ${_planta.frecuenciaRiego} días. Tu ${_planta.tipo} necesita agua.',
        scheduleTime: proximoRiegoDate,
      );

      print("🔔 Notificación programada para: $proximoRiegoDate");
      // ---------------------------------------------------------

      setState(() {
        // Actualizamos el modelo local para ver el cambio inmediato
        _planta = PlantaModel(
          id: _planta.id,
          usuarioId: _planta.usuarioId,
          nombre: _planta.nombre,
          tipo: _planta.tipo,
          ubicacion: _planta.ubicacion,
          imagenUrl: _planta.imagenUrl,
          frecuenciaRiego: _planta.frecuenciaRiego,
          ultimoRiego: nuevoRiego,
          creadoEn: _planta.creadoEn,
          coordenadas: _planta.coordenadas,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('¡Riego registrado! Te avisaremos el ${DateFormat('dd/MM').format(proximoRiegoDate)}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al regar: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Formateador de fecha simple
    final fechaFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(_planta.nombre),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FOTO GRANDE
            Hero(
              tag: _planta.id,
              child: Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(_planta.imagenUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ENCABEZADO
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _planta.nombre,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                      Chip(
                        label: Text(_planta.tipo),
                        backgroundColor: Colors.green[100],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // UBICACIÓN
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.grey),
                      const SizedBox(width: 5),
                      Text(
                        _planta.ubicacion,
                        style: const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                  const Divider(height: 30),

                  // ESTADO DE RIEGO
                  const Text("Estado del Riego", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Frecuencia:"),
                              Text("Cada ${_planta.frecuenciaRiego} días"),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Último riego:"),
                              Text(fechaFormat.format(_planta.ultimoRiego)),
                            ],
                          ),
                          const Divider(),
                          Center(
                            child: Text(
                              _calcularProximoRiego(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // BOTÓN DE ACCIÓN
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      onPressed: _isLoading ? null : _regarPlanta,
                      icon: const Icon(Icons.water_drop, color: Colors.white),
                      label: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("REGAR AHORA", style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}