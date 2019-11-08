node {
    checkout scm
    
    try {
        stage 'Run unit/integration tests'
        sh 'make test'    

        stage 'Build application artifacts'
        sh 'make build'   

        stage 'Create release environment and run acceptance test'
        sh 'make release'
  
        stage 'Tag and publish release images'
        sh "make tag latest \$(git rev-parse --short HEAD) \$(git tag --points-at HEAD)"
        sh "make buildtag master \$(git tag --points-at HEAD)"
        withEnv(["DOCKER_USER=${DOCKER_USER}", "DOCKER_PASSWORD=${DOCKER_PASSWORD}"]) {
            sh "make login"
        }
        sh 'make publish'  
        
    }
    
    finally {
        stage 'collect test reports'
        step([$class: 'JUnitResultArchiver', testResults: '**/reports/*.xml'])   
 
        stage 'Cleanup'
        sh 'make clean'
        sh 'make logout' 
    }
}