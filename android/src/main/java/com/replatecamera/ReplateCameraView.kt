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

@RequiresApi(Build.VERSION_CODES.N)
class ReplateCameraView @JvmOverloads constructor(
  context: Context, attrs: AttributeSet? = null, defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

  private lateinit var arFragment: ArFragment
  private var anchorNode: AnchorNode? = null
  private var spheres: MutableList<TransformableNode> = mutableListOf()
  private var gestureDetector: GestureDetector

  init {
    setupArFragment()
    requestCameraPermission()
    gestureDetector = GestureDetector(context, GestureListener())
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
    val radius = 0.13f
    val sphereRadius = 0.004f
    for (i in 0 until 72) {
      val angle = Math.toRadians((i * 5).toDouble()).toFloat()
      val x = radius * Math.cos(angle.toDouble()).toFloat()
      val z = radius * Math.sin(angle.toDouble()).toFloat()
      createSphere(Vector3(x, 0.10f, z))
    }
  }

  @RequiresApi(Build.VERSION_CODES.N)
  private fun createSphere(position: Vector3) {
    MaterialFactory.makeOpaqueWithColor(context, Color(android.graphics.Color.WHITE))
      .thenAccept { material ->
        val sphere = ShapeFactory.makeSphere(0.004f, position, material)
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
    return gestureDetector.onTouchEvent(event)
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
      return true
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
