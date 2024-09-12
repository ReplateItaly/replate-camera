package com.replatecamera

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.AttributeSet
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.widget.FrameLayout
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import com.google.ar.core.HitResult
import com.google.ar.sceneform.AnchorNode
import com.google.ar.sceneform.math.Vector3
import com.google.ar.sceneform.rendering.MaterialFactory
import com.google.ar.sceneform.rendering.ShapeFactory
import com.google.ar.sceneform.ux.ArFragment
import com.google.ar.sceneform.ux.TransformableNode
import com.google.ar.sceneform.rendering.Color
import kotlin.math.sqrt

@RequiresApi(Build.VERSION_CODES.N)
class ReplateCameraView @JvmOverloads constructor(
  context: Context, attrs: AttributeSet? = null, defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

  private lateinit var arFragment: ArFragment
  private var anchorNode: AnchorNode? = null
  private var spheres: MutableList<TransformableNode> = mutableListOf()
  private var gestureDetector: GestureDetector
  private var scaleDetector: ScaleGestureDetector
  private var sphereRadius = 0.004f
  private var sphereCircleRadius =  0.13f
  private var dragSpeed = 0.005f

  init {
    setupArFragment()
    requestCameraPermission()
    gestureDetector = GestureDetector(context, GestureListener())
    scaleDetector = ScaleGestureDetector(context, ScaleListener())
  }

  @RequiresApi(Build.VERSION_CODES.N)
  private fun setupArFragment() {
    arFragment = ArFragment()
    val fragmentManager = (context as FragmentActivity).supportFragmentManager
    fragmentManager.beginTransaction().replace(this.id, arFragment).commit()

    arFragment.arSceneView.scene.addOnUpdateListener { frameTime ->
      arFragment.onUpdate(frameTime)
      onUpdateFrame()
    }

    arFragment.setOnTapArPlaneListener { hitResult, plane, motionEvent ->
      if (anchorNode == null) {
        anchorNode = createAnchorNode(hitResult)
        createSpheres()
      }
    }
  }

  private fun createAnchorNode(hitResult: HitResult): AnchorNode {
    val anchor = hitResult.createAnchor()
    val anchorNode = AnchorNode(anchor)
    anchorNode.setParent(arFragment.arSceneView.scene)
    return anchorNode
  }

  @RequiresApi(Build.VERSION_CODES.N)
  private fun createSpheres() {
    for (i in 0 until 72) {
      val angle = Math.toRadians((i * 5).toDouble()).toFloat()
      val x = sphereCircleRadius * Math.cos(angle.toDouble()).toFloat()
      val z = sphereCircleRadius * Math.sin(angle.toDouble()).toFloat()
      createSphere(Vector3(x, 0.10f, z))
    }
  }

  @RequiresApi(Build.VERSION_CODES.N)
  private fun createSphere(position: Vector3) {
    MaterialFactory.makeOpaqueWithColor(context, Color(android.graphics.Color.WHITE))
      .thenAccept { material ->
        val sphere = ShapeFactory.makeSphere(sphereRadius, position, material)
        val node = TransformableNode(arFragment.transformationSystem)
        node.renderable = sphere
        node.setParent(anchorNode)
        spheres.add(node)
      }
  }

  private fun onUpdateFrame() {
    // Handle frame updates
  }

  override fun onTouchEvent(event: MotionEvent): Boolean {
    return scaleDetector.onTouchEvent(event) || gestureDetector.onTouchEvent(event)
  }

  private inner class GestureListener : GestureDetector.SimpleOnGestureListener() {
    override fun onSingleTapUp(event: MotionEvent): Boolean {
      return true
    }

    override fun onScroll(
      e1: MotionEvent?,
      e2: MotionEvent,
      distanceX: Float,
      distanceY: Float
    ): Boolean {
      // Assuming you have a reference to the AR scene view and the anchor entity
      val sceneView = arFragment.arSceneView
      val anchorEntity = anchorNode
      anchorEntity?.let {
        // Get the camera's transformation matrix
        val cameraTransform = sceneView.scene.camera.worldPosition

        if (e2.action == MotionEvent.ACTION_MOVE) {
          // Calculate the translation
          val translationX = -distanceX
          val translationY = -distanceY

          // Extract forward and right vectors from the camera transform matrix
          val forward = Vector3(
            -cameraTransform.x,
            0f,
            -cameraTransform.z
          ) // Assuming Y is up
          val right = Vector3(
            cameraTransform.x,
            0f,
            cameraTransform.z
          ) // Assuming Y is up

          // Normalize the vectors
          val forwardNormalized = normalize(forward)
          val rightNormalized = normalize(right)

          // Calculate the adjusted movement based on user input and camera orientation
          val adjustedMovement = Vector3(
            translationX * rightNormalized.x + translationY * forwardNormalized.x,
            0f, // Assuming you want to keep the movement in the horizontal plane
            -translationX * rightNormalized.z - translationY * forwardNormalized.z // Invert the z movement
          )

          // Update the position of the anchor entity
          val initialPosition = anchorEntity.worldPosition
          anchorEntity.worldPosition = Vector3.add(
            initialPosition,
            adjustedMovement.scaled(1f / dragSpeed)
          )

          // Reset translation
          e2.setLocation(0f, 0f)
        }
      }

      return true
    }

    private fun normalize(vector: Vector3): Vector3 {
      val length = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
      return Vector3(vector.x / length, vector.y / length, vector.z / length)
    }
  }

  private inner class ScaleListener : ScaleGestureDetector.SimpleOnScaleGestureListener() {
    override fun onScale(detector: ScaleGestureDetector): Boolean {
      return true
    }
  }

  private fun requestCameraPermission() {
    if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA)
      != PackageManager.PERMISSION_GRANTED
    ) {
      ActivityCompat.requestPermissions(context as Activity, arrayOf(Manifest.permission.CAMERA), 0)
    }
  }

  fun onRequestPermissionsResult(
    requestCode: Int, permissions: Array<out String>, grantResults: IntArray
  ) {
    if (requestCode == 0 && grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
      // Permission granted
    } else {
      // Permission denied
    }
  }
}
